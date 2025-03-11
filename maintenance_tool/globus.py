"""GLOBUS synchronisation tool.

This module provides a command line tool to synchronise local data in Globus Personal
Connect collection with the central shared Guest Collection attached to the Imperial
HPC project store.
"""

import time
import webbrowser
from dataclasses import dataclass
from pathlib import Path

import globus_sdk
import marshmallow_dataclass
import yaml
from marshmallow.exceptions import ValidationError


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
    authentication_token: str | None = None
    authentication_token_expiry: int | None = None
    transfer_token: str | None = None
    transfer_token_expiry: int | None = None
    user_uuid: str | None = None


def get_auth_tokens(config):
    """Use OAuth2 to get an authorisation code and exchange it for access tokens."""

    # Get the application client
    native_auth_client = globus_sdk.NativeAppAuthClient(config.app_client_uuid)
    scopes = build_scopes(config)

    # Obtain an authorisation code using a web browser
    native_auth_client.oauth2_start_flow(requested_scopes=scopes)
    auth_url = native_auth_client.oauth2_get_authorize_url()
    _ = input("Authentication required. Press return to open web browser.")
    webbrowser.open(auth_url)
    auth_code = input("Enter authorisation code: ")

    # Get authentication tokens and user id and package for return
    response = native_auth_client.oauth2_exchange_code_for_tokens(auth_code)

    tokens_by_resource = response.by_resource_server
    tokens_by_resource["user_uuid"] = response.decode_id_token()["sub"]

    return tokens_by_resource


def load_and_update_config(config_file_path: Path):
    """Load the configuration file.

    This method attempts to load the yaml configuration file and then attempts to create
    an instance of SyncConfig from the loaded data.

    Arg:
        config_file_path: Path to the configuration file
    """

    config_schema = marshmallow_dataclass.class_schema(SyncConfig)()

    with open(config_file_path) as cfp:
        try:
            config_data = yaml.safe_load(cfp)
        except yaml.YAMLError as excep:
            raise ValueError("Error reading configuration YAML: " + str(excep))

    try:
        config: SyncConfig = config_schema.load(data=config_data)
    except ValidationError as excep:
        raise ValueError("Invalid configuration data: " + str(excep))

    update_config_file = False

    # Has the local endpoint ID been set?
    if config.local_collection_uuid is None:
        # Don't know failure modes on this yet
        local = globus_sdk.LocalGlobusConnectPersonal()
        config.local_collection_uuid = local.endpoint_id
        update_config_file = True

    # If the authentication token is missing or the existing token has expired then get
    # new tokens
    if not (
        (config.authentication_token is not None)
        and (config.authentication_token is not None)
        and (config.authentication_token_expiry > int(time.time()))
    ):
        # Get and store the tokens
        tokens = get_auth_tokens(config)
        auth_tokens = tokens["auth.globus.org"]
        transfer_tokens = tokens["transfer.api.globus.org"]
        config.authentication_token = auth_tokens["access_token"]
        config.authentication_token_expiry = auth_tokens["expires_at_seconds"]
        config.transfer_token = transfer_tokens["access_token"]
        config.transfer_token_expiry = transfer_tokens["expires_at_seconds"]
        config.user_uuid = tokens["user_uuid"]

        update_config_file = True

    if update_config_file:
        with open(config_file_path, "w") as cfp:
            yaml.safe_dump(
                data=config_schema.dump(obj=config),
                stream=cfp,
            )

    return config


def build_scopes(config: SyncConfig) -> list:
    """Build the scopes list required for the synchronisation process.

    This is currently a bit of a mess while we work out what scopes are needed for the
    transfer operations.
    """

    # # Set up the scopes on the collections
    # remote_data_access = globus_sdk.scopes.GCSCollectionScopeBuilder(
    #     config.remote_collection_uuid
    # ).data_access

    # Add the transfer scope - the Guest Collection does not seem to depend on the data
    # access scope (unlike a Mapped Collection)
    transfer_scope = globus_sdk.scopes.TransferScopes.make_mutable("all")
    # transfer_scope.add_dependency(remote_data_access)

    return [
        "openid",
        "profile",
        "email",
        "urn:globus:auth:scope:auth.globus.org:view_identities",
        transfer_scope,
    ]


def globus_sync(config_file_path: Path) -> None:
    """Synchronize files to and from GLOBUS."""

    # Get a configuration object, updating any access tokens as needed.
    config = load_and_update_config(config_file_path=config_file_path)

    # Authenticate with the TransferClient and get information about the remote
    # endpoint
    transfer_authorizer = globus_sdk.AccessTokenAuthorizer(config.transfer_token)
    tc = globus_sdk.TransferClient(authorizer=transfer_authorizer)
    remote_info = tc.get_endpoint(config.remote_collection_uuid)

    # Attempt to authorise with the GCSClient - this is not authenticating.
    remote_authoriser = globus_sdk.AccessTokenAuthorizer(config.authentication_token)

    gc = globus_sdk.GCSClient(  # noqa: F841
        remote_info["gcs_manager_url"], authorizer=remote_authoriser
    )

    # Set up the transfer - this fails due to absence of ACL roles.
    tdata = globus_sdk.TransferData(
        transfer_client=tc,
        source_endpoint=config.remote_collection_uuid,
        destination_endpoint=config.local_collection_uuid,
        preserve_timestamp=True,
    )
    tdata.add_item("/ve_data_science/data/", "/~/testing/", recursive=True)

    # Raises globus_sdk.services.transfer.errors.TransferAPIError
    try:
        submit_result = tc.submit_transfer(tdata)  # noqa: F841
    except globus_sdk.services.transfer.errors.TransferAPIError as excep:
        print(excep.raw_json)
        raise
