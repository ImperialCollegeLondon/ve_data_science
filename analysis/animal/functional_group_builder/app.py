"""Streamlit tool for user-defined animal functional groups from SAFE traits."""

import csv
import sys
from importlib.metadata import version
from pathlib import Path

import pandas as pd
import streamlit as st
from virtual_ecosystem.models.animal.animal_traits import DietType

# The workflow repository is not installed as a Python package.
tools_src = Path(__file__).resolve().parents[3] / "tools/python/src"
if str(tools_src) not in sys.path:
    sys.path.insert(0, str(tools_src))

from ve_data_tools.animal_fg_builder import (  # noqa: E402
    BROAD_DIETS,
    DIETS,
    SOURCE,
    STRATA,
    TAXON_LEVELS,
    TEMPERATURE_FIELDS,
    TRAITS,
    BuiltGroup,
    Row,
    class_taxa,
    diet_options,
    export_groups,
    export_provenance,
    filter_safe,
    load_safe,
    observed_diets,
    rename_references,
    summarise_mass,
    taxonomic_options,
    validate_row,
)

st.set_page_config(page_title="SAFE animal functional-group builder", layout="wide")
st.title("Animal functional-group builder")
st.caption(
    f"SAFE evidence, user-defined groups. Installed VE: {version('virtual-ecosystem')}"
)


@st.cache_data
def read_source(path: str, encoding: str, modified: int) -> pd.DataFrame:
    """Cache the source by path, explicit encoding and modification time."""
    return load_safe(Path(path), encoding)


def main() -> None:
    """Render the evidence filters, group editor and optional downloads."""
    if "groups" not in st.session_state:
        st.session_state.groups = {}
    groups: dict[int, BuiltGroup] = st.session_state.groups
    if "next_id" not in st.session_state:
        st.session_state.next_id = 1
    if "pending_editor" in st.session_state:
        st.session_state.group_editor = st.session_state.pop("pending_editor")

    with st.sidebar:
        st.header("SAFE source")
        path = st.text_input("CSV path", str(SOURCE))
        encoding = st.selectbox("CSV encoding", ["cp1252", "utf-8-sig", "latin1"])
        st.info(
            "Mapping approximations: ground includes understory; "
            "canopy includes aerial. Dead wood maps to wood, fungi to fungi, "
            "soil to pom, roots/phloem to foliage, "
            "pollen to flowers. Review whether these suit your group."
        )
        st.caption(
            "TODO: review understory/aerial mappings and add finer VE diet tags, "
            "size bins and optional JSON provenance."
        )
        st.caption("Aquatic strata have no supported VE occupancy mapping.")
    try:
        source_path = Path(path).expanduser()
        data = read_source(str(source_path), encoding, source_path.stat().st_mtime_ns)
    except (OSError, UnicodeError, csv.Error, ValueError) as error:
        st.error(f"Cannot load SAFE source: {error}")
        st.stop()
    mappings = class_taxa(data)
    if not mappings:
        st.error("The source contains no supported animal classes.")
        st.stop()
    st.caption("Fish, missing classes and unsupported classes are excluded.")

    st.subheader("Your functional groups")
    if groups:
        st.dataframe(
            pd.DataFrame([group.row for group in groups.values()]), hide_index=True
        )
        st.warning(
            "Draft CSV: birth_mass is intentionally blank. Complete it before VE runs."
        )
        try:
            output = export_groups(list(groups.values()))
        except (ValueError, AttributeError) as error:
            st.error(f"Cannot export until corrected: {error}")
        else:
            st.download_button(
                "Download functional groups",
                output,
                "animal_functional_groups.csv",
                "text/csv",
            )
        if st.checkbox("Offer included-taxa and mass log"):
            st.download_button(
                "Download mass provenance",
                export_provenance(list(groups.values())),
                "animal_functional_groups_mass_provenance.csv",
                "text/csv",
            )
    else:
        st.info("Create your first group below. You decide how many groups to build.")

    edit_id = st.selectbox(
        "Create or edit a group",
        [0, *groups],
        format_func=lambda value: (
            "New group" if value == 0 else str(groups[value].row["name"])
        ),
        key="group_editor",
    )
    existing = groups.get(edit_id)
    prefix = f"edit_{edit_id or st.session_state.next_id}_"
    if existing and st.button("Remove this group"):
        del groups[edit_id]
        st.session_state.pending_editor = 0
        st.rerun()

    st.subheader("1. Taxonomy")
    chosen_class = st.selectbox(
        "Class",
        sorted(mappings),
        index=sorted(mappings).index(existing.taxonomy["class"]) if existing else None,
        key=prefix + "class",
    )
    if chosen_class is None:
        st.info("Choose an animal class to start.")
        st.stop()
    taxonomy = {"class": chosen_class}
    taxonomic_data = data[
        (data["kingdom"] == "Animalia") & (data["class"] == chosen_class)
    ]
    for level in TAXON_LEVELS[1:]:
        options = taxonomic_options(taxonomic_data, level)
        previous = existing.taxonomy.get(level) if existing else None
        custom_option = "Enter a custom value..."
        options.append(custom_option)
        previous_choice = previous if previous in options else custom_option
        chosen = st.selectbox(
            f"{level.title()} (optional)",
            options,
            index=options.index(previous_choice) if previous else None,
            key=prefix + level + "|" + "|".join(taxonomy.values()),
        )
        if chosen == custom_option:
            chosen = st.text_input(
                f"Custom {level}",
                value=previous if previous and previous not in options else "",
                key=prefix + "custom_" + level,
            ).strip()
            if not chosen:
                st.info(
                    f"Enter a custom {level}, or leave the optional level unselected."
                )
                st.stop()
        if chosen:
            taxonomy[level] = chosen.strip()
            taxonomic_data = taxonomic_data[taxonomic_data[level] == chosen.strip()]
    taxa = mappings[chosen_class]
    confirmed_taxa = st.checkbox(
        f"Confirm VE taxa: {taxa} (required)",
        value=existing is not None,
        key=prefix + "confirm_" + taxa,
        help="Tick to confirm the class-to-VE mapping before saving a group.",
    )
    if not confirmed_taxa:
        st.info("Required: confirm the mapped VE taxon before adding this group.")

    st.subheader("2. Strata")
    strata = st.multiselect(
        "Strata (at least one required; all selected strata must match)",
        list(STRATA),
        default=existing.strata if existing else [],
        key=prefix + "strata",
    )
    if not strata:
        st.info("Select at least one stratum.")
        st.stop()
    st.subheader("3. Broad and specific diets")
    broad = st.selectbox(
        "Broad diet",
        BROAD_DIETS,
        index=BROAD_DIETS.index(existing.broad_diet) if existing else None,
        key=prefix + "broad",
    )
    if broad is None:
        st.info("Select a broad diet.")
        st.stop()
    filtered = filter_safe(data, taxonomy, strata, broad)
    suggestions = observed_diets(filtered)
    st.write("Observed mapped tags:", ", ".join(suggestions) or "None")
    st.caption(
        "These are VE diet tags found in at least one SAFE row matching your "
        "taxonomy, strata and broad diet, not tags shared by every row."
    )
    selected_diets = st.multiselect(
        "Review specific diet tags (optional)",
        diet_options(),
        default=existing.diets if existing else [],
        key=prefix + "diets",
        help=(
            "Leave empty to export all observed mapped tags and retain all "
            "broad-filtered rows for mass."
        ),
    )
    if not selected_diets:
        st.session_state[prefix + "filter_diets"] = False
    filter_diets = st.checkbox(
        "Also require to match every selected detailed diet",
        value=existing.filter_diets if existing else False,
        key=prefix + "filter_diets",
        disabled=not selected_diets,
        help=(
            "Checked: narrow SAFE mass records to those matching every chosen tag. "
            "Unchecked: change only the exported diet, not the mass records."
        ),
    )
    filter_diets = filter_diets and bool(selected_diets)
    st.caption(
        "This checkbox adds detailed-diet filtering to the mass calculation. "
        "Without it, all rows matching taxonomy, strata and broad diet remain."
    )
    diets = selected_diets or suggestions
    if not selected_diets:
        st.info(
            "No specific selection: using all observed tags "
            "without narrowing mass rows."
        )
    if not diets:
        st.warning(
            "No mapped tags found. Choose specific VE tags to provide an output diet."
        )
    unmapped = [diet for diet in selected_diets if diet not in DIETS]
    if filter_diets and unmapped:
        st.error(
            f"No SAFE filter mapping for: {', '.join(unmapped)}. "
            "Disable diet filtering."
        )
        st.stop()
    if filter_diets:
        filtered = filter_safe(data, taxonomy, strata, broad, selected_diets)
    if broad in {"carnivore", "herbivore", "omnivore"}:
        if (
            diets
            and DietType.parse("_".join(diets)).coarse_category().name.lower() != broad
        ):
            st.warning(
                "The selected VE diet tags classify differently "
                "from your broad SAFE diet."
            )
    unobserved = set(diets).difference(suggestions)
    if unobserved:
        st.warning(
            "Selected tags not observed in matching SAFE rows: "
            f"{', '.join(sorted(unobserved))}"
        )

    st.subheader("4. Adult mass and source evidence")
    summary = summarise_mass(filtered)
    st.write(
        f"{len(filtered)} matching rows; "
        f"{len(summary.contributors)} unique mass contributors."
    )
    for warning in summary.warnings:
        st.warning(warning)
    with st.expander("Inspect matching SAFE records"):
        st.dataframe(filtered, hide_index=True)
    if summary.median_kg is None:
        st.warning(
            "No usable SAFE masses. Supply an adult mass; no broader-taxonomy fallback."
        )
        adult_mass = st.number_input(
            "User-supplied adult mass (kg)",
            min_value=0.0,
            value=float(existing.row["adult_mass"])
            if existing and existing.contributors.empty
            else None,
            format="%.9g",
            key=prefix + "mass",
        )
    else:
        adult_mass = summary.median_kg
        st.metric("Median adult mass (kg)", f"{adult_mass:.9g}")
        st.dataframe(
            summary.contributors[["taxon_name", "taxon_level", "mass_g", "mass_kg"]],
            hide_index=True,
        )

    st.subheader("5. Name and other VE traits")
    suggested_name = "_".join([*taxonomy.values(), *strata, broad]).replace(" ", "_")
    name = st.text_input(
        "Functional-group name",
        value=str(existing.row["name"]) if existing else suggested_name,
        key=prefix + "name",
    ).strip()
    row: Row = {"name": name, "taxa": taxa, "diet": "_".join(diets)}
    for column, enum in TRAITS.items():
        options = [member.value for member in enum]
        previous = existing.row[column] if existing else None
        row[column] = st.selectbox(
            column,
            options,
            index=options.index(previous) if previous in options else None,
            key=prefix + column,
        )
    offspring_names = [
        name,
        *(str(group.row["name"]) for key, group in groups.items() if key != edit_id),
    ]
    previous_offspring = (
        str(existing.row["offspring_functional_group"]) if existing else name
    )
    row["offspring_functional_group"] = st.selectbox(
        "offspring_functional_group",
        offspring_names,
        index=offspring_names.index(previous_offspring)
        if previous_offspring in offspring_names
        else 0,
        key=prefix + "offspring",
        help=(
            "Select self for direct development, "
            "or another retained group for metamorphosis."
        ),
    )
    row["vertical_occupancy"] = "_".join(strata)
    row["birth_mass"] = None
    row["adult_mass"] = adult_mass
    row["density_individuals_m2"] = st.number_input(
        "density_individuals_m2 (optional)",
        min_value=0.0,
        value=existing.row["density_individuals_m2"] if existing else None,
        format="%.9g",
        key=prefix + "density",
    )
    for column in TEMPERATURE_FIELDS:
        row[column] = st.number_input(
            f"{column} (optional, Celsius)",
            value=existing.row.get(column) if existing else None,
            format="%.9g",
            key=prefix + column,
            help="Enter an empirical value, or leave blank for VE to estimate it.",
        )
    ready = confirmed_taxa and bool(diets) and adult_mass is not None and adult_mass > 0
    ready = ready and all(row[column] is not None for column in TRAITS)
    if st.button("Save group" if existing else "Add group", disabled=not ready):
        if any(
            group.row["name"] == name for key, group in groups.items() if key != edit_id
        ):
            st.error("That name already exists. Choose a unique name.")
        else:
            try:
                validate_row(row)
            except (ValueError, AttributeError) as error:
                st.error(str(error))
            else:
                if existing:
                    rename_references(
                        list(groups.values()), str(existing.row["name"]), name
                    )
                    if row["offspring_functional_group"] == existing.row["name"]:
                        row["offspring_functional_group"] = name
                groups[edit_id or st.session_state.next_id] = BuiltGroup(
                    row,
                    taxonomy,
                    strata,
                    broad,
                    selected_diets,
                    filter_diets,
                    summary.contributors.copy(),
                )
                if not existing:
                    st.session_state.next_id += 1
                st.session_state.pending_editor = edit_id
                st.rerun()
    st.caption(
        "Confirm taxa and complete each trait dropdown to save. Specific diets "
        "are optional when observed tags are available."
    )


main()
