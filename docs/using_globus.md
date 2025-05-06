# Using GLOBUS

We are using the [GLOBUS system](https://www.globus.org/) to curate the data used in the
Virtual Ecosystem data science repository.

* All paths to data files within the repository should be relative paths to a data file
  location in the `data` directory.
* However, to avoid adding large and/or binary data files to the GitHub repository
  itself, the contents of the `data` directory are managed using GLOBUS.

At any point, we should be able to re-run analyses by cloning the code from the GitHub
repository and then populating the `data` directory using GLOBUS.

## GLOBUS Overview

GLOBUS is a web-based system that provides access to data files.

* GLOBUS does not store the files itself - it is not cloud storage - but it
  provides configured connections to data in existing networked storage.

* GLOBUS also manages access privileges and authentication to connect to data: users
  register with GLOBUS and can then be granted access to data sets

A single data repositories is called **a collection**. A collection is basically just a
configured connection to a particular set of files. Individual users can then be given
access to collections. Users can also be made part of a group and that group can be
given access to collections.

For the VE Data Science team, we are using GLOBUS to connect to a collection of files
hosted on the Imperial College London Research Data Store.

## The GLOBUS web application

Once you have logged into the GLOBUS web application, you will end up on a page with a
set of different tabs on the left hand side.

### The Collections tab

The Collections tab is used to provide an overview of the data collections that you have
access to.

* Start by opening the Collections tab and then clicking the "Shared with you" Button.
  The URL
  [https://app.globus.org/collections?scope=shared-with-me](https://app.globus.org/collections?scope=shared-with-me
  ) should take you straight to this page.

* You should see the "Virtual Ecosystem data science" collection.
* If you click on that link, you'll see an unfriendly overview page with collection
  details.
* You should also see a button marked "Open in File Manager" - click this!

### The File Manager

The File Manager tab is used to view the files and folders within a collection and to
interact with the data repository. You can access the tab from a particular collection
(as above), from the tab button on the left or directly using the URL
[https://app.globus.org/file-manager](https://app.globus.org/file-manager)

Once you have opened a collection in the pane then you should be able to see the files
and folders in the collection and can open folders to explore the data.

> [!NOTE] Collection path
> When you open the VE Data Science collection, you will see that it shows a path at the
> top: `ve_data_science/data`. This is because the collection shares _all_ of the files
> in our Research Data Store. This include a clone of the `ve_data_science` repo but
> also some other data resources. You can move up to look at the contents of those
> directories, but the collection is set up to go to the `data` directory by default.
