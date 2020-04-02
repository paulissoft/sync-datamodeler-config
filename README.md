# Oracle SQL Developer Data Modeler configuration

A project to share Oracle SQL Datamodeler settings and scripts.
Oracle SQL Developer Data Modeler has several global configuration items like:
* preferences
* design rules and transformations
* default domains

Besides that there are also design preferences and glossaries but you can
store them in a version control system easily unlike the global configuration.

The official way to share the global configuration between computers is to use
the various import and export utilities from the Data Modeler. However this is
quite time consuming and thus error prone.

An easier approach is to just backup these settings to a directory you specify
as a command line option (ideally under version control). Then you can restore
them when needed. This project tries to accomplish just that: KISS.

## Usage

The programming language Perl is used for the backup and restore script
datamodeler_config.pl.

For help type:

$ perl datamodeler_config.pl --help

## Global configuration

The configuration can be found in the following directories:
* datamodeler/types (inside the datamodeler installation home)
* %APPDATA%\Oracle SQL Developer Data Modeler\system<VER_FULL> (for Windows)
* ~/.oraclesqldeveloperdatamodeler/system<VER_FULL> (for Unix)

The version VER_FULL can be found in the installation directory of the Data Modeler
where the file datamodeler/bin/version.properties contains a line like this:

  VER_FULL=18.4.0.339.1532

