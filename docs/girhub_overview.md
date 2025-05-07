# Github Overview

!!! IMPORTANT

    This is currently a draft document

Github is an online platform for code sharing and collaboration. Multiple developers can
work on a project at once, make changes on their own copy of the code (called a
"branch"), get feedback on the changes from other team members, and then "merge" their
changes into the core code-base. This page walks you through basic git and github
functionality used for the project.

## Lingo

* **Repository** (repo): the codebase.
* **Branch**: a copy of the codebase where local changes don't immediately impact the
  main branch
* **Commit**: a package of changes that you're satisfied with, and then group them
  together and label with a description.
* **Pull request**: a functioning chunk of code that can be safely merged into the main
  codebase without breaking any other functionality
* **Push**: send your commits to the upstream version of your branch (the online
  version)

## Getting started

1. Make a github account and login.
2. Find the repository that you want to work on. Click on the green "code" button and
   copy the link under clone.
    * If your github account usees two-factor authentication or single sign-on you will
      need to use the SSH version, otherwise you can use HTTPS.
    * If you use the SSH version, your computer will need to communicate with github
      automatically to authenticate you when you make changes from your desktop. To do
      this you need to generate a SSH key and add it to your account. Github has a
      tutorial
      [here](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).
3. Decide where you want the repo to be stored on your local computer. Open a terminal
   window and navigate to this location (`cd FOLDERNAME` moves you into a folder, and
   `cd ..` moves you backwards.)
4. Once you have found the folder, paste `git clone SSH/HTTPS REPO URL` into the
   terminal. This should download a copy of the up-to-date code into your local
   computer.
5. Open VS Code (or another processor such as PyCharm) and open the folder that you just
   downloaded.

You can now add files, make changes, and work on the codebase. Once you're ready to
share those changes, go to the next section!

## Checkout a new branch

By default, when you download the code you will be on the main branch. This branch
includes all the approved code. Never work directly on the main branch - you should
always create your own branch, and merge it into main only later once the code is ready
and has received approval.

1. Check what branch you're on. VS Code has the name of the branch in the bottom left,
   or you can run `git branch` in the terminal.
2. Pull the most recent version of main. Before you create a new branch, make sure your
   main is up-to-date. This will be the copy of the code that you start from. To pull,
   use the refresh button in the bottom left of VS Code, or run `git pull` in the
   terminal.
3. Create a new branch. You can create a new branch in VS Code by clicking on the branch
   name and then the "Create a new branch..." option that should show up. Otherwise, run
   `git checkout -b BRANCH NAME` in the terminal. Your branch name doesn't need to be
   long, but should be descriptive enough so that you remember what you're doing on it
   in case you switch between branches.

## Commit and push your code

Committing your code is a way to package up some changes that should all be logically
grouped together and describing what you've done. A commit is a helpful way for other
developers to quickly look at the change you've made with the intention you had, so that
they can easily review the changes.

1. First, check exactly what changes git has tracked. This ensures that you don't commit
   anything you don't mean to (like old work, commented out code, etc.) You can do this
   in VS Code in the "Source Control" tab. Anything labelled "changes" is work that
   hasn't yet been marked as ready to add to a commit. Anything labeled "staged changes"
   includes work that you have indicated is ready to commit, but has not yet been
   committed.
2. Check over your changes and stage them. Click on the files under changes and look
   through what has been added (will be noted with blue highlight next to the line
   numbers). As long as you are happy, you can stage the changes by clicking the "+"
   button next to the file.
3. Once you are ready to commit all your staged changes, press the blue commit button.
   This will open a new file where you can type a commit message (a brief description of
   what work has been done). Then, click the check mark button.
4. Push your changes to github. To send your changes to github, press the "publish"
   button. This sends a copy of the work on your branch to github, so anyone can see
   what you have been doing.

You can also perform these tasks from the terminal window if you prefer. Some basic
commands are `git status` to see what branch you're on and what files have changed; `git
diff` to see what your changes are; `git add FILENAME` to stage changes in that file;
`git commit -m COMMIT MESSAGE` to commit all the staged changes; and `git push` to push
your changes to github.

## Creating a pull request and merging

1. Once you are ready for a code review (and ultimately for your code to be merged into
   the main branch), go on github and create a pull request (PR). You can do this from
   the pull request tab, or if you've recently pushed from a local branch, github will
   prompt you to make a PR from that branch. When you're making a PR, you want to merge
   your branch into main.
2. Add a description of what the PR accomplishes and request review from the relevant
   team members.
3. Wait for review. Once the reviewers give approval (or if you complete their
   requests), you can merge from the PR page. This sends your updates into the main
   branch.

## Start it all over

Once you complete your task and are ready for the next one, you can start the process
over. A few things to remember...

* Always create new branches off of main. Go into VS Code (or the terminal) and switch
  to the main branch. Pull the latest version before creating a new branch.

!!! NOTE "TODO"

    Handling merge conflicts
