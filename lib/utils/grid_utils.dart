import 'dart:math';

/// Calculates optimal grid dimensions for bubble layouts
/// Returns a map with 'rows', 'columns', and 'cellSize'
Map<String, dynamic> calculateGridDimensions(
  int totalItems,
  double screenWidth,
  double screenHeight,
  {String viewType = 'year'} // 'year' or 'month'
) {
  if (viewType == 'month') {
    // Month view: fixed 7 columns (days of week), dynamic rows
    int columns = 7;
    int rows = (totalItems / columns).ceil();
    double cellSize = min(screenWidth / columns, screenHeight / rows);
    return {
      'rows': rows,
      'columns': columns,
      'cellSize': cellSize,
    };
  } else {
    // Year view: aim for ~20 columns × 19 rows for 365/366 days
    int targetColumns = 20;
    int targetRows = (totalItems / targetColumns).ceil();

    // Adjust based on screen dimensions
    double cellWidth = screenWidth / targetColumns;
    double cellHeight = screenHeight / targetRows;
    double cellSize = min(cellWidth, cellHeight);

    // Recalculate columns and rows based on optimal cell size
    int columns = (screenWidth / cellSize).floor();
    int rows = (totalItems / columns).ceil();

    // Ensure we don't exceed screen height
    while (rows * cellSize > screenHeight && rows > 1) {
      rows--;
      columns = (totalItems / rows).ceil();
      cellSize = min(screenWidth / columns, screenHeight / rows);
    }

    return {
      'rows': rows,
      'columns': columns,
      'cellSize': cellSize,
    };
  }
}