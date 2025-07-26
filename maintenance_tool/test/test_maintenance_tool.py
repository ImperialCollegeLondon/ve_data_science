"""Testing the maintenance tool CLI."""


def test_maintenance_tool():
    """Test the maintenance tool endpoints."""
    from maintenance_tool.maintenance_tool import maintenance_tool_cli

    val = maintenance_tool_cli(
        ["check_data_directory", "data/primary/soil/carbon_use_efficiency"]
    )

    assert val
