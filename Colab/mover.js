/**
 * 🚀 МЕГА-СКРИПТ СИНХРОНІЗАЦІЇ (З ПІДТРИМКОЮ ПЕРЕЗАПИСУ, UPSERT ТА КЛОНУВАННЯ ФОРМАТІВ)
 */

// =========================================================================
// ⚙️ ЄДИНИЙ КОНФІГУРАТОР ЗАДАЧ
// =========================================================================
const CONFIG = {
  
  // 1️⃣ ЗАДАЧА: СКЛАД / ЗАЛИШКИ
  ZALYSHKY: {
    ENABLED: true,
    TITLE: "Склад (Залишки)",
    MODE: "OVERWRITE", 
    SOURCE_URL: "https://docs.google.com/spreadsheets/d/1hIyUSO_FYyaM4FIc6prSahlt62qxNvXOrAUIV8kh4U0/edit?gid=0#gid=0",
    SOURCE_SHEET_NAME: "Залишки (всі)",
    TARGET_URL: "https://docs.google.com/spreadsheets/d/1kPFNolw6IbC_l5mgwEph_vxzFGlGb6hF03XG2zV2U98/edit", 
    TARGET_SHEET_NAME: "Залишки (всі)",
    KEY_COLUMN_NAME: "id", 
    FORMAT_HEADERS: true
  },

  // 2️⃣ ЗАДАЧА: ПОСТАЧАННЯ
  POSTACHANNYA: {
    ENABLED: true,
    TITLE: "Постачання",
    MODE: "OVERWRITE",
    SOURCE_URL: "https://docs.google.com/spreadsheets/d/1yHi1I3F9qhm-V1AdqaklhwO8DZGjlqEkHwqDt35QzH8/edit?gid=1733056911#gid=1733056911",
    SOURCE_SHEET_NAME: "Постачання (всі)",
    TARGET_URL: "https://docs.google.com/spreadsheets/d/1V9DP0mfOiTBsxMubeCC4V8CbtIk73w0OKAryvKntk8U/edit?gid=868738502#gid=868738502",
    TARGET_SHEET_NAME: "Постачання (всі)",
    KEY_COLUMN_NAME: "order_date",
    FORMAT_HEADERS: true
  },

  // 3️⃣ ЗАДАЧА: ПОСТАЧАННЯ 14Д
  POSTACHANNYA_14D: {
    ENABLED: true,
    TITLE: "Постачання 14д",
    MODE: "OVERWRITE",
    SOURCE_URL: "https://docs.google.com/spreadsheets/d/1yHi1I3F9qhm-V1AdqaklhwO8DZGjlqEkHwqDt35QzH8/edit?gid=1733056911#gid=1733056911",
    SOURCE_SHEET_NAME: "Постачання 14д",
    TARGET_URL: "https://docs.google.com/spreadsheets/d/1V9DP0mfOiTBsxMubeCC4V8CbtIk73w0OKAryvKntk8U/edit?gid=868738502#gid=868738502",
    TARGET_SHEET_NAME: "Постачання 14д",
    KEY_COLUMN_NAME: "product_id",
    FORMAT_HEADERS: true
  },

  // 4️⃣ ЗАДАЧА: ПОСТАЧАННЯ 30Д
  POSTACHANNYA_30D: {
    ENABLED: true,
    TITLE: "Постачання 30д",
    MODE: "OVERWRITE",
    SOURCE_URL: "https://docs.google.com/spreadsheets/d/1yHi1I3F9qhm-V1AdqaklhwO8DZGjlqEkHwqDt35QzH8/edit?gid=1733056911#gid=1733056911",
    SOURCE_SHEET_NAME: "Постачання 30д",
    TARGET_URL: "https://docs.google.com/spreadsheets/d/1V9DP0mfOiTBsxMubeCC4V8CbtIk73w0OKAryvKntk8U/edit?gid=868738502#gid=868738502",
    TARGET_SHEET_NAME: "Постачання 30д",
    KEY_COLUMN_NAME: "product_id",
    FORMAT_HEADERS: true
  },

  // 5️⃣ ЗАДАЧА: ЗАПАСИ
  ZAPASY: {
    ENABLED: true,
    TITLE: "Запаси",
    MODE: "OVERWRITE",
    SOURCE_URL: "https://docs.google.com/spreadsheets/d/1yHi1I3F9qhm-V1AdqaklhwO8DZGjlqEkHwqDt35QzH8/edit?gid=1733056911#gid=1733056911",
    SOURCE_SHEET_NAME: "Запаси",
    TARGET_URL: "https://docs.google.com/spreadsheets/d/1V9DP0mfOiTBsxMubeCC4V8CbtIk73w0OKAryvKntk8U/edit?gid=868738502#gid=868738502",
    TARGET_SHEET_NAME: "Запаси",
    KEY_COLUMN_NAME: "product_id",
    FORMAT_HEADERS: true
  },

  // 6️⃣ ЗАДАЧА: ОПРИБУТКУВАННЯ (ВСІ)
  OPRYBUTKUVANNYA: {
    ENABLED: true,
    TITLE: "Оприбуткування (всі)",
    MODE: "OVERWRITE",
    SOURCE_URL: "https://docs.google.com/spreadsheets/d/1NTB_t8qmMz0jd2f9FWngk6X3O7O2uSTKhiL0PWKRYRU/edit?gid=1466911334#gid=1466911334",
    SOURCE_SHEET_NAME: "Оприбуткування (всі)",
    TARGET_URL: "https://docs.google.com/spreadsheets/d/1kPFNolw6IbC_l5mgwEph_vxzFGlGb6hF03XG2zV2U98/edit",
    TARGET_SHEET_NAME: "Оприбуткування (всі)",
    KEY_COLUMN_NAME: "op_id",
    FORMAT_HEADERS: true
  },

  // 7️⃣ ЗАДАЧА: ОПРИБУТКУВАННЯ 2026
  OPRYBUTKUVANNYA_2026: {
    ENABLED: true,
    TITLE: "Оприбуткування 2026",
    MODE: "OVERWRITE",
    SOURCE_URL: "https://docs.google.com/spreadsheets/d/1NTB_t8qmMz0jd2f9FWngk6X3O7O2uSTKhiL0PWKRYRU/edit?gid=1466911334#gid=1466911334",
    SOURCE_SHEET_NAME: "Оприбуткування 2026",
    TARGET_URL: "https://docs.google.com/spreadsheets/d/1kPFNolw6IbC_l5mgwEph_vxzFGlGb6hF03XG2zV2U98/edit",
    TARGET_SHEET_NAME: "Оприбуткування 2026",
    KEY_COLUMN_NAME: "op_id",
    FORMAT_HEADERS: true
  },

  // 8️⃣ ЗАДАЧА: ОПРИБУТКУВАННЯ 30Д
  OPRYBUTKUVANNYA_30D: {
    ENABLED: true,
    TITLE: "Оприбуткування 30д",
    MODE: "OVERWRITE",
    SOURCE_URL: "https://docs.google.com/spreadsheets/d/1NTB_t8qmMz0jd2f9FWngk6X3O7O2uSTKhiL0PWKRYRU/edit?gid=1466911334#gid=1466911334",
    SOURCE_SHEET_NAME: "Оприбуткування 30д",
    TARGET_URL: "https://docs.google.com/spreadsheets/d/1kPFNolw6IbC_l5mgwEph_vxzFGlGb6hF03XG2zV2U98/edit",
    TARGET_SHEET_NAME: "Оприбуткування 30д",
    KEY_COLUMN_NAME: "product_id",
    FORMAT_HEADERS: true
  }
};

// =========================================================================
// 🎬 ГОЛОВНІ КНОПКИ ЗАПУСКУ
// =========================================================================

function runAllSyncs() {
  Logger.log("🎬 === СТАРТ ЗАГАЛЬНОЇ СИНХРОНІЗАЦІЇ ===");
  for (const taskKey in CONFIG) {
    const task = CONFIG[taskKey];
    if (task.ENABLED) {
      Logger.log(`\n▶️ Обробка задачі: [${task.TITLE}] (Режим: ${task.MODE})`);
      syncSheetDataEngine_(task);
    } else {
      Logger.log(`\n⏸️ Задачу [${task.TITLE}] пропущено`);
    }
  }
  Logger.log("\n🏁 === УСІ ЗАДАЧІ УСПІШНО ВИКОНАНО ===");
}

function runOnlyZalyshky() { syncSheetDataEngine_(CONFIG.ZALYSHKY); }
function runOnlyPostachannya() { syncSheetDataEngine_(CONFIG.POSTACHANNYA); }
function runOnlyPostachannya14d() { syncSheetDataEngine_(CONFIG.POSTACHANNYA_14D); }
function runOnlyPostachannya30d() { syncSheetDataEngine_(CONFIG.POSTACHANNYA_30D); }
function runOnlyZapasy() { syncSheetDataEngine_(CONFIG.ZAPASY); }
function runOnlyOprybutkuvannya() { syncSheetDataEngine_(CONFIG.OPRYBUTKUVANNYA); }
function runOnlyOprybutkuvannya2026() { syncSheetDataEngine_(CONFIG.OPRYBUTKUVANNYA_2026); }
function runOnlyOprybutkuvannya30d() { syncSheetDataEngine_(CONFIG.OPRYBUTKUVANNYA_30D); }

// =========================================================================
// 🛠 УНІВЕРСАЛЬНИЙ ДВИГУН (ENGINE)
// =========================================================================

function syncSheetDataEngine_(task) {
  try {
    // 1. Відкриваємо Джерело
    let sourceSS;
    try {
      sourceSS = SpreadsheetApp.openByUrl(task.SOURCE_URL);
    } catch (e) {
      throw new Error(`[${task.TITLE}] Не вдалося відкрити SOURCE_URL: ` + e.toString());
    }

    const sourceSheet = sourceSS.getSheetByName(task.SOURCE_SHEET_NAME);
    if (!sourceSheet) {
      throw new Error(`[${task.TITLE}] Аркуш '${task.SOURCE_SHEET_NAME}' не знайдено в Джерелі!`);
    }

    // 2. Відкриваємо Призначення
    let targetSS;
    if (task.TARGET_URL && task.TARGET_URL.trim() !== "") {
      try {
        targetSS = SpreadsheetApp.openByUrl(task.TARGET_URL);
      } catch (e) {
        throw new Error(`[${task.TITLE}] Не вдалося відкрити TARGET_URL: ` + e.toString());
      }
    } else {
      targetSS = SpreadsheetApp.getActiveSpreadsheet();
    }

    let targetSheet = targetSS.getSheetByName(task.TARGET_SHEET_NAME);
    if (!targetSheet) {
      Logger.log(`➕ Аркуш '${task.TARGET_SHEET_NAME}' не знайдено. Створюємо новий...`);
      targetSheet = targetSS.insertSheet(task.TARGET_SHEET_NAME);
    }

    // 3. Зчитуємо Джерело (ЗНАЧЕННЯ + ФОРМАТИ)
    const sourceRange = sourceSheet.getDataRange();
    const sourceData = sourceRange.getValues();
    const sourceFormats = sourceRange.getNumberFormats(); // 🔥 Беремо оригінальні формати

    if (sourceData.length === 0 || (sourceData.length === 1 && sourceData[0].join("").trim() === "")) {
      Logger.log(`⚠️ Джерело порожнє. Задачу [${task.TITLE}] пропущено.`);
      return;
    }

    const sourceHeaders = sourceData[0];
    const sourceRows = sourceData.slice(1);
    const sourceRowFormats = sourceFormats.slice(1); // Формати для рядків
    Logger.log(`📥 Зчитуємо з джерела: ${sourceRows.length} рядків, ${sourceHeaders.length} колонок.`);

    // 4. РЕЖИМ 1: ПОВНЕ ПЕРЕЗАПИСУВАННЯ (OVERWRITE)
    if (task.MODE === "OVERWRITE") {
      Logger.log("🧹 Очищаємо цільовий аркуш перед заповненням...");
      
      const activeFilter = targetSheet.getFilter();
      if (activeFilter) activeFilter.remove();
      
      targetSheet.clearContents();
      targetSheet.clearFormats(); // Чистимо старі формати

      // Записуємо нові дані разом з оригінальними форматами
      writeAndTrimSheet_(targetSheet, sourceData, sourceFormats);
      applyFormatting_(targetSheet, sourceData.length, sourceHeaders.length, task.FORMAT_HEADERS);

      Logger.log(`✅ [${task.TITLE}] Повне перезаписування успішно завершено!`);
      return;
    }

    // 5. РЕЖИМ 2: РОЗУМНЕ ОНОВЛЕННЯ (UPSERT)
    const targetRange = targetSheet.getDataRange();
    const targetData = targetRange.getValues();
    const targetFormats = targetRange.getNumberFormats(); // Поточні формати цілі
    
    if (targetData.length === 0 || (targetData.length === 1 && targetData[0].join("").trim() === "")) {
      Logger.log("ℹ️ Аркуш призначення порожній. Виконуємо первинний запис...");
      writeAndTrimSheet_(targetSheet, sourceData, sourceFormats);
      applyFormatting_(targetSheet, sourceData.length, sourceHeaders.length, task.FORMAT_HEADERS);
      Logger.log(`✅ [${task.TITLE}] Первинний запис виконано!`);
      return;
    }

    const targetHeaders = targetData[0];
    const cleanKeyName = String(task.KEY_COLUMN_NAME).trim().toLowerCase();
    
    let keyColIndexSource = sourceHeaders.findIndex(h => String(h).trim().toLowerCase() === cleanKeyName);
    let keyColIndexTarget = targetHeaders.findIndex(h => String(h).trim().toLowerCase() === cleanKeyName);

    if (keyColIndexSource === -1 || keyColIndexTarget === -1) {
      Logger.log(`⚠️ Ключ '${task.KEY_COLUMN_NAME}' не знайдено. Використовуємо 1-шу колонку (A).`);
      keyColIndexSource = 0;
      keyColIndexTarget = 0;
    }

    const targetMap = new Map();
    for (let i = 1; i < targetData.length; i++) {
      const keyVal = String(targetData[i][keyColIndexTarget]).trim();
      if (keyVal !== "") targetMap.set(keyVal, i);
    }

    let updatedCount = 0;
    let addedCount = 0;

    const colMapping = sourceHeaders.map(h => {
      const cleanH = String(h).trim().toLowerCase();
      return targetHeaders.findIndex(th => String(th).trim().toLowerCase() === cleanH);
    });

    sourceRows.forEach((sourceRow, rowIdx) => {
      const keyVal = String(sourceRow[keyColIndexSource]).trim();
      const sRowFormat = sourceRowFormats[rowIdx]; // Відповідний рядок форматів

      if (keyVal !== "" && targetMap.has(keyVal)) {
        const targetRowIdx = targetMap.get(keyVal);
        colMapping.forEach((targetColIdx, sourceColIdx) => {
          if (targetColIdx !== -1) {
            targetData[targetRowIdx][targetColIdx] = sourceRow[sourceColIdx];
            targetFormats[targetRowIdx][targetColIdx] = sRowFormat[sourceColIdx]; // Клонуємо формат
          }
        });
        updatedCount++;
      } else {
        const newTargetRow = new Array(targetHeaders.length).fill("");
        const newTargetFormat = new Array(targetHeaders.length).fill(""); // Дефолтний формат
        colMapping.forEach((targetColIdx, sourceColIdx) => {
          if (targetColIdx !== -1) {
            newTargetRow[targetColIdx] = sourceRow[sourceColIdx];
            newTargetFormat[targetColIdx] = sRowFormat[sourceColIdx]; // Клонуємо формат
          }
        });
        targetData.push(newTargetRow);
        targetFormats.push(newTargetFormat); // Додаємо формати для нового рядка
        addedCount++;
      }
    });

    Logger.log(`🔄 Оновлено: ${updatedCount} | ➕ Додано: ${addedCount}`);

    // Записуємо оновлені масиви даних та форматів
    writeAndTrimSheet_(targetSheet, targetData, targetFormats);
    applyFormatting_(targetSheet, targetData.length, targetHeaders.length, task.FORMAT_HEADERS);

    Logger.log(`✅ [${task.TITLE}] Оновлення завершено!`);

  } catch (error) {
    Logger.log(`❌ ПОМИЛКА [${task.TITLE}]: ` + error.message);
  }
}

/**
 * ✂️ Підрізання порожніх клітинок ТА встановлення значень/форматів
 */
function writeAndTrimSheet_(sheet, data, formats) {
  const numRows = data.length;
  const numCols = data[0].length;

  const currentMaxRows = sheet.getMaxRows();
  const currentMaxCols = sheet.getMaxColumns();

  if (currentMaxRows < numRows) {
    sheet.insertRowsAfter(currentMaxRows, numRows - currentMaxRows);
  }
  if (currentMaxCols < numCols) {
    sheet.insertColumnsAfter(currentMaxCols, numCols - currentMaxCols);
  }

  const range = sheet.getRange(1, 1, numRows, numCols);

  // 🔥 МАГІЯ ТУТ: Застосовуємо формати ДО того, як записуємо значення.
  // Це забороняє Таблицям самостійно перетворювати "31.12" в дати або ламати дроби!
  if (formats && formats.length === numRows && formats[0].length === numCols) {
    range.setNumberFormats(formats);
  }

  range.setValues(data);

  const updatedMaxRows = sheet.getMaxRows();
  const updatedMaxCols = sheet.getMaxColumns();

  if (updatedMaxRows > numRows) {
    sheet.deleteRows(numRows + 1, updatedMaxRows - numRows);
  }
  if (updatedMaxCols > numCols) {
    sheet.deleteColumns(numCols + 1, updatedMaxCols - numCols);
  }
}

/**
 * 🎨 Оформлення шапки
 */
function applyFormatting_(sheet, numRows, numCols, allowFormat) {
  if (!allowFormat || numRows === 0) return;

  sheet.setFrozenRows(1);

  const headerRange = sheet.getRange(1, 1, 1, numCols);
  headerRange.setBackground("#F1F3F4")
             .setFontColor("#202124")
             .setFontWeight("bold")
             .setHorizontalAlignment("center")
             .setVerticalAlignment("middle");

  const activeFilter = sheet.getFilter();
  if (!activeFilter) {
    sheet.getRange(1, 1, numRows, numCols).createFilter();
  }
}