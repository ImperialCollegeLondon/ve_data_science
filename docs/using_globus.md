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

Once you have logged into the GLOBUS web application, you will end up on a page with a
set of different tabs on the left hand side.

## The Collections tab

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

## The File Manager

The File Manager tab is used to view the files and folders within a collection and to
interact with the data repository. You can access the tab from a particular collection
(as above), from the tab button on the left or directly using the URL
[https://app.globus.org/file-manager](https://app.globus.org/file-manager)

Once you have opened a collection in the pane then you should be able to see the files
and folders in the collection and can open folders to explore the data.

!!! alert "Collection paths"

    When you open the VE Data Science collection, you will see that it shows a path at the
    top: `ve_data_science/data`. This is because the collection shares _all_ of the files
    in our Research Data Store. This include a clone of the `ve_data_science` repo but
    also some other data resources. You can move up to look at the contents of those
    directories, but the collection is set up to go to the `data` directory by default.

### File Manager actions

The bar in the centre of the file manager provides action buttons to work with files and
folders.

* **New Folder**, **Rename** and **Delete Selected** can be used with any selected
   folder or file in the collection. You'd need a very good reason to rename or delete
   files in the collection!

* **Download** and **Upload** can only be used with single files: these allow you to
  drop a single file from any location into a folder in the collection or download a
  file.

These tools may be all you need for day to day work - if you have a few files to upload
this may well be what you want to do. However, if you want to upload a more complex
set of files or download a large number of files, this is going to be a problem.

This is where the **Transfer or Sync to...** option comes in - it allows files and
folders to be copied between **two collections**. To do so, you need to configure your
own computer as a collection.

## Globus Connect Personal

The Globus Connect Personal application
[https://www.globus.org/globus-connect-personal](https://www.globus.org/globus-connect-personal)
is a local application that you install to your computer that sets up a GLOBUS
collection on your computer.

* Download and install the program.
* When you open it for the first time, it will ask you to log in with your GLOBUS
  credentials:
  * This will first take you to the GLOBUS website to authorise your GLOBUS account
    to create and manage a collection.
  * It will then ask for the collection details to create on your computer.
* It will then start the Globus Connect Personal application.

If you now go to the web application and look at the collections administered by you,
you should see the a new Private Mapped Connection:

[https://app.globus.org/collections?scope=administered-by-me](https://app.globus.org/collections?scope=administered-by-me)

In the File Manager tab of the web application, you can now select your personal
collection and use the File Manager action buttons to manage your files and transfer
folders between the two collections.

!!! Warning "Local file access permissions"

    By default, Globus Connect Personal (GCP) has access to your home directory. Only you
    have access to the collection, but you can also configure GCP to only be able to
    access a subset of files. Under the `GCP > Preferences` settings, you can select the
    Access tab and specify which files GCP can access _and_ whether GCP is allowed to
    write to those folders.

### The GLOBUS Transfer system

Transfer is used to copy files from a source collection to a destination collection.
Here, you could be uploading a folder from your personal collection (source) to the RDS
repo (destination) or downloading data from the RDS (source) to your local collection
(destination) for analsysis. Or possibly doing both to synchronise the two folders!

To transfer files or folders between collections:

* Select the files or folders on the source collection
* In the destination folder, open the location where the selected data will be
  transferred. **Do not_ select the folders or files on the destination** but instead
  make sure you have the location that you want to copy to open.

  For example, if you are synchronising the `data/derived` data folder, you will need to
  select the `derived` folder in the source collection, but just have the `data` folder
  open in the destination. If you do not do this then the data will be transfered _into_
  the selected folder.

* Press the "Start button" above the source collection. GLOBUS will schedule and run the
  transfer in the background: you can open the activity monitor link to see the progress
  of the transfer.
