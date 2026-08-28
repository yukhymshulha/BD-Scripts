#!/usr/bin/env node
// Git "clean" filter for .ipynb files: strips cell outputs and execution_count
// before the file is staged/committed, so re-running a notebook locally
// doesn't create noisy diffs. Reads the notebook JSON from stdin, writes the
// stripped version to stdout. Registered via .gitattributes + `git config`
// (see README for the one-time setup command).

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  let notebook;
  try {
    notebook = JSON.parse(input);
  } catch (e) {
    // Not valid JSON (or empty) - pass through unchanged rather than corrupt the file
    process.stdout.write(input);
    return;
  }

  for (const cell of notebook.cells || []) {
    if (cell.cell_type === 'code') {
      cell.outputs = [];
      cell.execution_count = null;
    }
  }
  if (notebook.metadata && notebook.metadata.widgets) {
    delete notebook.metadata.widgets;
  }

  process.stdout.write(JSON.stringify(notebook, null, 1) + '\n');
});
