/**
 * Adds mail merge-friendly currency columns next to the selected range.
 *
 * Usage:
 * 1. Select the cells that contain currency values (include headers if desired).
 * 2. Run the `createMailMergeCurrencyColumns` function from Extensions → Apps Script.
 * 3. For each selected column, a new helper column is inserted on the right that
 *    contains the display text of each cell (including currency symbols) stored
 *    as plain text so mail merges keep the formatting.
 */
function createMailMergeCurrencyColumns() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const range = sheet.getActiveRange();

  if (!range) {
    throw new Error('Please select the currency cells you want to export.');
  }

  const numRows = range.getNumRows();
  const numCols = range.getNumColumns();

  if (numRows === 0 || numCols === 0) {
    throw new Error('The selected range is empty.');
  }

  const lastColumn = range.getLastColumn();
  const displayValues = range.getDisplayValues();
  const headerRow = range.getRow();

  // Insert the same number of columns to the right of the selection.
  sheet.insertColumnsAfter(lastColumn, numCols);

  const helperRange = sheet.getRange(headerRow, lastColumn + 1, numRows, numCols);
  helperRange.setValues(displayValues);
  helperRange.setNumberFormat('@'); // Keep the display value as text.

  // Copy headers with a suffix so it is easy to reference during mail merge.
  if (numRows >= 1) {
    const headers = range.offset(0, 0, 1, numCols).getDisplayValues()[0];
    const helperHeaders = headers.map(function (header) {
      return header ? header + ' (Mail Merge)' : 'Mail Merge';
    });
    helperRange.offset(0, 0, 1, numCols).setValues([helperHeaders]);
  }

  // Ensure the helper columns are visible and auto-sized for convenience.
  sheet.autoResizeColumns(lastColumn + 1, numCols);
}
