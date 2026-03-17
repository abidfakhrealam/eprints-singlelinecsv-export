# eprints-singlelinecsv-export
EPrints plugin for exporting one EPrint record as a single-line CSV row, available in both standard export options and the Generic Reporting Framework.


# EPrints Single Line CSV Export Plugin

This plugin adds a **Single Line CSV export option** in EPrints.

It works in:

- **Standard Export Options** (search results, browse results, individual record export)
- **Generic Reporting Framework** (Admin → Reports)

---

## 🚀 Features

- Exports **one EPrint record per CSV row**
- Flattens compound fields like:
  - creators
  - editors
  - contributors
  - jgucreators
- Supports:
  - `creators_name`
  - `creators_id`
  - `creators_orcid`
  - similar projections for editors, contributors, and jgucreators
- Converts multi-value fields into semicolon-separated values
- Renders `subjects` as human-readable labels
- Normalizes ORCID values
- Produces UTF-8 CSV output

---

## 📁 Files Included

### Core export plugin
`perl_lib/EPrints/Plugin/Export/SingleLineCSV.pm`

Provides the actual Single Line CSV export in standard EPrints export options.

### Report wrapper plugin
`lib/plugins/EPrints/Plugin/Export/Report/SingleLineCSV.pm`

Integrates the plugin into the Generic Reporting Framework.

### Configuration files
- `cfg/z_reports.pl`
- `cfg/z_single_line_csv.pl`

---

## ⚙️ Installation

### 1. Install Generic Reporting Framework

Install the **Generic Reporting Framework** from the EPrints Bazaar via Admin UI.

---

### 2. Copy plugin files

Copy:

- `perl_lib/EPrints/Plugin/Export/SingleLineCSV.pm`  
  → `/opt/eprints3/perl_lib/EPrints/Plugin/Export/SingleLineCSV.pm`

- `lib/plugins/EPrints/Plugin/Export/Report/SingleLineCSV.pm`  
  → `/opt/eprints3/lib/plugins/EPrints/Plugin/Export/Report/SingleLineCSV.pm`

---

### 3. Add configuration files

Copy:

- `cfg/z_single_line_csv.pl`  
  → `/opt/eprints3/archives/<archive_id>/cfg/cfg.d/z_single_line_csv.pl`

Update or edit:

- `/opt/eprints3/archives/<archive_id>/cfg/cfg.d/z_reports.pl`

---

### 4. Enable plugin in report configuration

Ensure the following line exists in `z_reports.pl`:

```perl
$c->{plugins}{"Export::Report::SingleLineCSV"}{params}{disable} = 0;

Also add it to export plugins:

$c->{eprint_report}->{export_plugins} = [ qw(
    Export::Report::CSV
    Export::Report::HTML
    Export::Report::JSON
    Export::Report::SingleLineCSV
)];

---

### 5. Enable standard export plugin

In: z_single_line_csv.pl:
$c->{plugins}->{"Export::SingleLineCSV"}->{params}->{disable} = 0;


### 5. Reload EPrints
epadmin reload <archive_id>
