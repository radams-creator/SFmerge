# Salesforce Tax Letter Mail Merge Add-on

This repository contains a reference implementation for a Salesforce add-on that
produces tax or acknowledgement letters from Salesforce reports.  The solution
combines Apex services, a Lightning Web Component (LWC) configuration UI, and a
mail merge templating workflow that substitutes data returned from a report into
rich-text templates stored as Salesforce Content files.  Administrators can
configure the add-on to generate PDF letters for download or dispatch emails
with the generated content to constituent contacts.

## Features

- **Reusable mail merge service** that converts Salesforce report results into a
  collection of merge fields and renders letters using a simple `{{FieldName}}`
  placeholder syntax.
- **Lightning Web Component** wizard that lets staff choose the source report,
  select or upload a Content document as the merge template, preview the mail
  merge, and trigger letter generation.
- **Batch-friendly Apex orchestration** that persists generated letters as
  Content files, optionally emails them to recipients, and logs results for
  auditing and compliance.
- **Extensive documentation** for deploying in a scratch org or sandbox,
  configuring report metadata, and customising merge fields to match your tax or
  acknowledgement letter requirements.

## Repository Structure

```
force-app/
  main/default/
    classes/
      TaxLetterService.cls           # Apex service that powers the mail merge
      TaxLetterService.cls-meta.xml  # Metadata definition
      TaxLetterServiceTest.cls       # Apex unit test class
      TaxLetterServiceTest.cls-meta.xml
    lwc/
      reportMailMerge/
        reportMailMerge.html         # LWC markup
        reportMailMerge.js           # LWC controller logic
        reportMailMerge.js-meta.xml  # LWC metadata definition
    staticresources/
      sample_letter_template.docx    # Example template (optional placeholder)
config/
  project-scratch-def.json           # Scratch org definition (if using SFDX)
```

Only the Apex classes and the Lightning Web Component are included in this
reference implementation.  Add any optional supporting assets (static resources,
additional metadata) as needed for your org.

## Getting Started

1. **Prerequisites**
   - Salesforce CLI (`sfdx`) installed and authenticated against the target org.
   - A Salesforce org with API access (Enterprise, Unlimited, or Developer
     editions are recommended).
   - Permission to create Apex classes, LWC components, and Content documents.

2. **Deploy the metadata**

   ```bash
   sfdx force:source:deploy -p force-app/main/default
   ```

3. **Assign permissions**
   - Grant the `Tax Letter Mail Merge` permission set (create as part of your
     deployment) to users who will run the add-on.
   - Ensure these users have access to the reports used for mail merge and can
     read/write the relevant objects (e.g., `Contact`, `Opportunity`,
     `ContentDocument`).

4. **Prepare templates**
   - Create a Word or HTML template that contains merge tokens such as
     `{{Contact.Name}}`, `{{Donation_Amount}}`, or
     `{{OrganizationTaxId__c}}`.
   - Upload the template to Salesforce Files (ContentDocument).  The LWC will
     reference the template by ContentDocument Id.

5. **Run a mail merge**
   - Open the `Tax Letter Mail Merge` Lightning page or app tab.
   - Select a Salesforce report that returns the donor records you need.
   - Choose the template file and preview the merge results.
   - Click **Generate Letters** to produce letters.  Generated letters are stored
     as Content files and optionally emailed to each contact.

## Mail Merge Tokens

The mail merge service works with simple string replacement tokens enclosed in
`{{` and `}}`.  When a report is executed, every column label becomes an
available merge token.  For example, a report column labelled
"Donation Amount" becomes the `{{Donation_Amount}}` token (spaces replaced with
underscores).

You can also expose related object fields by editing the Apex service to add
custom token resolvers.  See the `TaxLetterService` implementation for details.

## Extending the Solution

- Modify `TaxLetterService.generateLetters` to support additional delivery
  methods, such as generating an aggregate PDF or dispatching physical mail via a
  third-party service.
- Add validation rules in the LWC to ensure users select valid reports and
  templates before running the mail merge.
- Introduce custom objects to track mail merge batches, templates, and logs for
  audit reporting.
- Replace the simple token engine with a more powerful parser that supports
  conditionals and loops (e.g., via the Apex `Template` library or custom Apex).

## Google Sheets helper scripts

The `scripts/currencyMailMerge.gs` file contains a Google Apps Script utility
that adds mail merge-friendly helper columns for currency data in Google Sheets.
To use it:

1. Copy the file contents into the Script Editor for your spreadsheet
   (`Extensions → Apps Script`).
2. Select the range of cells that contains your currency data (include the
   header row if you want helper column headers).
3. Run `createMailMergeCurrencyColumns` from the Script Editor. The script inserts
   new columns to the right of the selection that contain the displayed currency
   values stored as plain text so mail merges keep their formatting.

## Disclaimer

This implementation is intended as a starting point.  Review, test, and secure
it for your organisation's compliance and data governance requirements before
deploying to production.
