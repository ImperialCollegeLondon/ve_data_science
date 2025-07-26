"""GLOBUS synchronisation tool.

This module provides a command line tool to synchronise local data in Globus Personal
Connect collection with the central shared Guest Collection attached to the Imperial
HPC project store.
"""

from importlib import resources
from pathlib import Path
from typing import ClassVar

import globus_sdk
import yaml
from marshmallow import Schema
from marshmallow.exceptions import ValidationError
from marshmallow_dataclass import dataclass


@dataclass
class SyncConfig:
    """Synchronisation config dataclass.

    This dataclass is used to maintain the configuration identities and tokens needed to
    interact with the GLOBUS system.

    The app and remote collection details are required but the other attributes can be
    populated by authentication.
    """

    app_client_uuid: str
    app_client_name: str
    remote_collection_uuid: str
    local_collection_uuid: str | None = None

    Schema: ClassVar[type[Schema]]


def load_config(config_file_path: Path | None = None):
    """Load the configuration file.

    This method attempts to load the yaml configuration file and then attempts to create
    an instance of SyncConfig from the loaded data.

    Arg:
        config_file_path: Path to the configuration file
    """

    if config_file_path is None:
        maintenance_tool_root = Path(str(resources.files("maintenance_tool")))
        config_file_path = maintenance_tool_root / "globus_config.yaml"

    if not config_file_path.exists():
        raise ValueError("GLOBUS config file not found")

    with open(config_file_path) as cfp:
        try:
            config_data = yaml.safe_load(cfp)
        except yaml.YAMLError as excep:
            raise ValueError("Error reading configuration YAML: " + str(excep))

    try:
        config: SyncConfig = SyncConfig.Schema().load(data=config_data)
    except ValidationError as excep:
        raise ValueError("Invalid configuration data: " + str(excep))

    # Handle missing local collection UUID
    if config.local_collection_uuid is None:
        # Retrieve the local collection UUID using the globus_sdk and set it
        local = globus_sdk.LocalGlobusConnectPersonal()
        config.local_collection_uuid = local.endpoint_id

        # Save the updated config back to the original path to update it
        with open(config_file_path, "w") as cfg_out:
            yaml.safe_dump(
                data=SyncConfig.Schema().dump(config),
                stream=cfg_out,
            )

    return config


def get_authenticated_transfer_client(config: SyncConfig) -> globus_sdk.TransferClient:
    """Generate an authenticated GLOBUS Transfer client object.

    The authentication process has multiple steps, requiring authorisation of several
    different permissions to access the collection. This function was developed with
    support by the GLOBUS development team to interact with the web authorisation
    process for GLOBUS.

    Args:
        config: A SyncConfig instance providing connection data.

    """

    # Create a user application
    user_app = globus_sdk.UserApp(
        app_name=config.app_client_name, client_id=config.app_client_uuid
    )

    # Use that to create a GLOBUS transfer client
    client = globus_sdk.TransferClient(app=user_app)

    # Try to run an operation on the client and then handle authorisation errors
    try:
        _ = client.operation_ls(config.remote_collection_uuid)

    except globus_sdk.TransferAPIError as err:
        # Look for the specific case of additional authorisation parameters required in
        # the exception information and then use that to drive a fresh authentication
        # sequence via the web API. This requires user interaction at the command line.
        if err.info.authorization_parameters:
            print("An authorization requirement was not met. Logging in again...")

            # Convert the authentication error information in the exception to the
            # Globus Auth Requirements Errors (GARE) class, which provides an interface
            # to the required parameters that need to be used to login.
            gare = globus_sdk.gare.to_gare(err)
            params = gare.authorization_parameters  # type: ignore [union-attr]

            # Explicitly set 'prompt=login' to guarantee a fresh login without reliance
            # on any existing browser session.
            params.prompt = "login"

            # Pass these additional parameters into client via a login flow for the user
            # application
            user_app.login(auth_params=params)

        # otherwise, there are no authorization parameters, so reraise the error
        else:
            raise

    # The client should now be authorized
    try:
        _ = client.operation_ls(config.remote_collection_uuid)
    except Exception:
        raise RuntimeError("Could not connect to GLOBUS transfer")

    return client


def globus_sync(config: SyncConfig, transfer_client: globus_sdk.TransferClient) -> None:
    """Synchronize files to and from GLOBUS.

    In progress.

    Args:
        config: A SyncConfig instance providing connection data.
        transfer_client: An authenticated GLOBUS transfer client.

    """

    # Set up the Transfer Data object from remote to local
    tdata = globus_sdk.TransferData(
        transfer_client=transfer_client,
        source_endpoint=config.remote_collection_uuid,
        destination_endpoint=config.local_collection_uuid,
        preserve_timestamp=True,
    )

    # Add the remote data directory to the transfer data request
    tdata.add_item(
        "/ve_data_science/data/",
        "/Users/dorme/Research/Virtual_Rainforest/ve_data_science/data/testing",
        recursive=True,
    )

    # Submit the request and handle errors
    try:
        submit_result = transfer_client.submit_transfer(tdata)  # noqa: F841
    except globus_sdk.services.transfer.errors.TransferAPIError as excep:
        print(excep.raw_json)
        raise
