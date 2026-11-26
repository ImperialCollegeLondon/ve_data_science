"""Focused filtering, evidence-export and GUI tests for the SAFE builder."""

import csv
import io

import pandas as pd
import pytest
from streamlit.testing.v1 import AppTest
from ve_data_tools.animal_fg_builder import (
    DIETS,
    ROOT,
    SCHEMA,
    SOURCE,
    TRAITS,
    BuiltGroup,
    class_taxa,
    csv_preview,
    export_groups,
    export_provenance,
    filter_safe,
    load_safe,
    observed_diets,
    rename_references,
    summarise_mass,
    taxonomic_options,
)
from virtual_ecosystem.models.animal.animal_traits import DietType

APP = ROOT / "analysis/animal/functional_group_builder/app.py"


@pytest.fixture
def records():
    """Create synthetic rows with the real SAFE header and explicit missing flags."""
    columns = load_safe(SOURCE).columns

    def make(*overrides):
        rows = []
        for i, override in enumerate(overrides):
            row = dict.fromkeys(columns, "NA")
            row.update(
                field_name=str(i + 1),
                kingdom="Animalia",
                phylum="Chordata",
                **{"class": "Aves"},
                order="Passeriformes",
                family="Birdidae",
                genus="Bird",
                species=f"Bird {i}",
                taxon_name=f"Bird {i}",
                taxon_level="species",
                BodyMass="1000",
                StraTerr="terrestrial",
                TrophHerb="herbivore",
                DietFrug="frugivore",
            )
            row.update(override)
            rows.append(row)
        return pd.DataFrame(rows, columns=columns)

    return make


def test_safe_parser_metadata_encoding_and_errors(tmp_path, records):
    """Read metadata and cp1252 names; reject malformed data and incorrect units."""
    frame = records({"taxon_name": "Bird café"})
    path = tmp_path / "traits.csv"

    def write(units="g", short=False):
        with path.open("w", encoding="cp1252", newline="") as handle:
            writer = csv.writer(handle)
            unit_row = [""] * len(frame.columns)
            unit_row[0] = "units"
            unit_row[list(frame.columns).index("BodyMass")] = units
            writer.writerow(unit_row)
            writer.writerow(frame.columns)
            values = frame.iloc[0].tolist()
            writer.writerow(values[:-1] if short else values)

    write()
    assert load_safe(path)["taxon_name"].iloc[0] == "Bird café"
    with pytest.raises(UnicodeError):
        load_safe(path, "utf-8-sig")
    write("kg")
    with pytest.raises(ValueError, match="grams"):
        load_safe(path)
    write(short=True)
    with pytest.raises(ValueError, match="column count"):
        load_safe(path)


def test_exclusive_diets_and_categorical_na(records):
    """Exclude mixed Sap/Para flags and distinguish omnivores from carnivores."""
    data = records(
        {"TrophCarn": "carnivore", "TrophHerb": "NA"},
        {},
        {"TrophCarn": "1", "TrophHerb": "1"},
        {"TrophSap": "saprophage", "TrophHerb": "0"},
        {"TrophPara": "parasite", "TrophHerb": "NA"},
        {"TrophToid": "parasitoid", "TrophHerb": "NA"},
        {"TrophSap": "1", "TrophPara": "1", "TrophHerb": "NA"},
        {"TrophSap": "1"},
        {"TrophToid": "parasitoid"},
    )
    for i, category in enumerate(
        ["carnivore", "herbivore", "omnivore", "saprophage", "parasite", "parasitoid"]
    ):
        found = filter_safe(data, {"class": "Aves"}, ["ground"], category)
        assert found["field_name"].tolist() == [str(i + 1)]


def test_taxonomy_strata_and_optional_diet_filters(records):
    """Cascades use exact taxonomy; OR within mapped tags, AND across selections."""
    data = records(
        {"StraTerr": "NA", "StraUnd": "understory", "StraAer": "aerial"},
        {"StraArb": "arboreal", "DietFoli": "folivore"},
        {"StraArb": "arboreal", "species": "Other species"},
    )
    assert taxonomic_options(data, "species") == ["Bird 0", "Bird 1", "Other species"]
    found = filter_safe(data, {"class": "Aves"}, ["ground", "canopy"], "herbivore")
    assert len(found) == 3
    assert (
        len(
            filter_safe(
                data, {"class": "Aves"}, ["ground"], "herbivore", ["fruit", "foliage"]
            )
        )
        == 1
    )
    assert filter_safe(
        data, {"class": "Aves", "species": "Custom"}, ["ground"], "herbivore"
    ).empty
    with pytest.raises(ValueError, match="stratum"):
        filter_safe(data, {"class": "Aves"}, [], "herbivore")


def test_species_identity_first_valid_mass_and_exclusions(records):
    """Equal-mass taxa count, but repeated taxon records do not weight medians."""
    data = records(
        {"species": "Same species", "BodyMass": "NA"},
        {"species": "Same species", "BodyMass": "100"},
        {"species": "Same species", "BodyMass": "900"},
        {"BodyMass": "100"},
        {
            "BodyMass": "1000",
            "taxon_level": "morphospecies",
            "species": "NA",
            "taxon_name": "Morph A",
        },
        {"BodyMass": "-1"},
        {"BodyMass": "inf"},
        {"BodyMass": "20000", "taxon_level": "genus"},
    )
    summary = summarise_mass(data)
    assert summary.median_kg == pytest.approx(0.1)
    assert summary.contributors["mass_g"].tolist() == [100, 100, 1000]
    assert any("Conflicting masses" in message for message in summary.warnings)
    assert any("higher-rank" in message for message in summary.warnings)
    assert summarise_mass(data.iloc[[0, 5, 6, 7]]).median_kg is None


def test_class_mapping_and_accepted_diet_tags(records):
    """Map multiple invertebrate classes without exposing fish or plants."""
    data = records(
        {},
        {"class": "Insecta", "phylum": "Arthropoda"},
        {"class": "Clitellata", "phylum": "Annelida"},
        {"class": "Actinopterygii"},
        {"class": "NA"},
        {"class": "PlantClass", "kingdom": "Plantae"},
    )
    assert class_taxa(data) == {
        "Aves": "bird",
        "Insecta": "invertebrate",
        "Clitellata": "invertebrate",
    }
    assert DietType.parse("_".join(DIETS))


def test_exact_export_and_provenance_after_edits(records):
    """Renames, removals and manual masses preserve row/evidence correspondence."""
    summary = summarise_mass(records({}))
    row = {
        "name": "group",
        "taxa": "bird",
        "diet": "fruit",
        "offspring_functional_group": "group",
        "vertical_occupancy": "ground",
        "birth_mass": None,
        "adult_mass": summary.median_kg,
        "density_individuals_m2": None,
        **{column: next(iter(enum)).value for column, enum in TRAITS.items()},
    }
    group = BuiltGroup(
        row,
        {"class": "Aves"},
        ["ground"],
        "herbivore",
        ["fruit"],
        False,
        summary.contributors,
    )
    rename_references([group], "group", "renamed")
    group.row["name"] = "renamed"
    with SCHEMA.open() as handle:
        header = next(csv.reader(handle))
    output = export_groups([group])
    assert next(csv.reader(io.StringIO(output))) == header
    assert csv_preview(output)["birth_mass"].iloc[0] == ""
    provenance = csv_preview(export_provenance([group]))
    assert provenance["functional_group"].tolist() == ["renamed"]
    assert provenance["mass_kg"].tolist() == [1.0]
    group.contributors = pd.DataFrame()
    manual = csv_preview(export_provenance([group]))
    assert manual["taxon_name"].iloc[0] == ""
    assert manual["mass_source"].iloc[0] == "user"
    assert csv_preview(export_provenance([])).empty
    group.row["offspring_functional_group"] = "missing"
    with pytest.raises(ValueError, match="offspring"):
        export_groups([group])


def test_gui_create_edit_remove_and_custom_mass():
    """Exercise the GUI against real SAFE data, including a custom species."""
    app = AppTest.from_file(str(APP), default_timeout=30)
    app.run()
    assert not app.exception

    def select(label, value):
        next(widget for widget in app.selectbox if widget.label == label).set_value(
            value
        )

    select("Class", "Mammalia")
    app.run()
    next(
        widget for widget in app.checkbox if widget.label.startswith("Confirm VE")
    ).check()
    app.multiselect[0].set_value(["ground"])
    app.run()
    select("Broad diet", "herbivore")
    app.run()
    assert any(
        widget.disabled
        for widget in app.checkbox
        if widget.label == "Also require to match every selected detailed diet"
    )
    for column, enum in TRAITS.items():
        select(column, next(iter(enum)).value)
    app.run()
    next(button for button in app.button if button.label == "Add group").click().run()
    assert not app.exception
    assert len(app.session_state["groups"]) == 1
    saved = app.session_state["groups"][1]
    expected_rows = filter_safe(
        load_safe(SOURCE), {"class": "Mammalia"}, ["ground"], "herbivore"
    )
    assert saved.diets == []
    assert saved.row["diet"] == "_".join(observed_diets(expected_rows))
    assert saved.row["adult_mass"] == summarise_mass(expected_rows).median_kg
    select("Create or edit a group", 1)
    app.run()
    next(
        widget for widget in app.text_input if widget.label == "Functional-group name"
    ).set_value("Renamed")
    next(button for button in app.button if button.label == "Save group").click().run()
    assert not app.exception
    assert app.session_state["groups"][1].row["name"] == "Renamed"
    next(
        button for button in app.button if button.label == "Remove this group"
    ).click().run()
    assert not app.exception
    assert not app.session_state["groups"]
    select("Class", "Mammalia")
    app.run()
    next(
        widget for widget in app.selectbox if widget.label.startswith("Species (")
    ).set_value("Enter a custom value...")
    app.run()
    next(
        widget for widget in app.text_input if widget.label == "Custom species"
    ).set_value("Custom species")
    app.run()
    next(
        widget for widget in app.checkbox if widget.label.startswith("Confirm VE")
    ).check()
    app.multiselect[0].set_value(["ground"])
    app.run()
    select("Broad diet", "herbivore")
    app.run()
    assert not app.exception
    next(
        widget
        for widget in app.number_input
        if widget.label == "User-supplied adult mass (kg)"
    ).set_value(2.5)
    next(
        widget for widget in app.multiselect if widget.label.startswith("Review")
    ).set_value(["fruit"])
    for column, enum in TRAITS.items():
        select(column, next(iter(enum)).value)
    app.run()
    next(button for button in app.button if button.label == "Add group").click().run()
    assert not app.exception
    assert app.session_state["groups"][2].row["adult_mass"] == 2.5
    assert app.session_state["groups"][2].contributors.empty


def test_gui_optional_diets_and_mass_filter(tmp_path, records):
    """Detailed selections change mass only when their additional filter is checked."""
    data = records(
        {"BodyMass": "1000"},
        {"BodyMass": "9000", "DietFrug": "NA", "DietFoli": "folivore"},
        {"BodyMass": "2000", "DietFoli": "folivore"},
    )
    path = tmp_path / "source.csv"
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        units = [""] * len(data.columns)
        units[0] = "units"
        units[list(data.columns).index("BodyMass")] = "g"
        writer.writerow(units)
        writer.writerow(data.columns)
        writer.writerows(data.values)
    app = AppTest.from_file(str(APP), default_timeout=30)
    app.run()
    next(widget for widget in app.text_input if widget.label == "CSV path").set_value(
        str(path)
    )
    app.run()
    next(widget for widget in app.selectbox if widget.label == "Class").set_value(
        "Aves"
    )
    app.run()
    next(
        widget for widget in app.checkbox if widget.label.startswith("Confirm VE")
    ).check()
    app.multiselect[0].set_value(["ground"])
    app.run()
    next(widget for widget in app.selectbox if widget.label == "Broad diet").set_value(
        "herbivore"
    )
    app.run()
    next(
        widget for widget in app.multiselect if widget.label.startswith("Review")
    ).set_value(["fruit"])
    for column, enum in TRAITS.items():
        next(widget for widget in app.selectbox if widget.label == column).set_value(
            next(iter(enum)).value
        )
    app.run()
    next(button for button in app.button if button.label == "Add group").click().run()
    assert not app.exception
    assert app.session_state["groups"][1].row["diet"] == "fruit"
    assert app.session_state["groups"][1].row["adult_mass"] == 2.0
    next(
        widget for widget in app.selectbox if widget.label == "Create or edit a group"
    ).set_value(1)
    app.run()
    next(
        widget
        for widget in app.checkbox
        if widget.label == "Also require to match every selected detailed diet"
    ).check().run()
    next(button for button in app.button if button.label == "Save group").click().run()
    assert not app.exception
    assert app.session_state["groups"][1].row["adult_mass"] == 1.5
    assert len(app.session_state["groups"][1].contributors) == 2
