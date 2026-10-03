package org.techwithkaushik.student_comparison;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.graphics.pdf.PdfDocument;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.print.PageRange;
import android.print.PrintAttributes;
import android.print.PrintDocumentAdapter;
import android.print.PrintDocumentInfo;
import android.print.PrintManager;
import android.webkit.MimeTypeMap;

import androidx.annotation.NonNull;

import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "student_comparison/native_print";
    private static final String PREFS = "student_comparison_print";
    private static final String DEFAULT_SETTINGS =
            "{\"paper\":\"A4\",\"orientation\":\"auto\",\"margin\":5,\"fontSize\":10,\"autoFit\":true,\"repeatHeader\":true,\"pageNumber\":true}";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    switch (call.method) {
                        case "printTable":
                            try {
                                Map<String, Object> data = (Map<String, Object>) call.arguments;
                                printTable(data);
                                result.success(true);
                            } catch (Exception e) {
                                result.error("PRINT_FAILED", e.getMessage(), null);
                            }
                            break;
                        case "savePrintSettings":
                            saveSettings((Map<String, Object>) call.arguments);
                            result.success(true);
                            break;
                        case "getPrintSettings":
                            result.success(readSettings());
                            break;
                        case "savePrintColumnPreferences":
                            saveColumnPreferences((Map<String, Object>) call.arguments);
                            result.success(true);
                            break;
                        case "getPrintColumnPreferences":
                            result.success(readColumnPreferences((Map<String, Object>) call.arguments));
                            break;
                        default:
                            result.notImplemented();
                    }
                });
    }

    private void saveColumnPreferences(Map<String, Object> values) {
        String source = strOr(values.get("source"), "PSP").toUpperCase();
        List<String> fields = stringList(values.get("fields"));
        Map<String, Object> headers = map(values.get("headers"));

        JSONArray fieldArray = new JSONArray();
        for (String field : fields) {
            fieldArray.put(field);
        }

        JSONObject headerObject = new JSONObject();
        for (Map.Entry<String, Object> entry : headers.entrySet()) {
            try {
                headerObject.put(entry.getKey(), str(entry.getValue()));
            } catch (Exception ignored) {
                // Ignore an individual malformed header rather than losing the preset.
            }
        }

        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString("columns_" + source, fieldArray.toString())
                .putString("headers_" + source, headerObject.toString())
                .apply();
    }

    private Map<String, Object> readColumnPreferences(Map<String, Object> values) {
        String source = strOr(values.get("source"), "PSP").toUpperCase();
        android.content.SharedPreferences p =
                getSharedPreferences(PREFS, Context.MODE_PRIVATE);

        if (!p.contains("columns_" + source)) {
            return null;
        }

        List<String> fields = new ArrayList<>();
        Map<String, Object> headers = new HashMap<>();

        try {
            JSONArray fieldArray = new JSONArray(
                    p.getString("columns_" + source, "[]"));
            for (int i = 0; i < fieldArray.length(); i++) {
                fields.add(fieldArray.optString(i, ""));
            }
        } catch (Exception ignored) {
            // Return an empty preset if the stored value is invalid.
        }

        try {
            JSONObject headerObject = new JSONObject(
                    p.getString("headers_" + source, "{}"));
            java.util.Iterator<String> keys = headerObject.keys();
            while (keys.hasNext()) {
                String key = keys.next();
                headers.put(key, headerObject.optString(key, ""));
            }
        } catch (Exception ignored) {
            // Return headers that could be recovered.
        }

        Map<String, Object> out = new HashMap<>();
        out.put("fields", fields);
        out.put("headers", headers);
        return out;
    }

    private void saveSettings(Map<String, Object> values) {
        android.content.SharedPreferences.Editor e =
                getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit();
        e.putString("paper", String.valueOf(values.getOrDefault("paper", "A4")));
        e.putString("orientation", String.valueOf(values.getOrDefault("orientation", "auto")));
        e.putInt("margin", asInt(values.get("margin"), 5));
        e.putFloat("fontSize", asFloat(values.get("fontSize"), 10f));
        e.putBoolean("autoFit", asBool(values.get("autoFit"), true));
        e.putBoolean("repeatHeader", asBool(values.get("repeatHeader"), true));
        e.putBoolean("pageNumber", asBool(values.get("pageNumber"), true));
        e.apply();
    }

    private Map<String, Object> readSettings() {
        android.content.SharedPreferences p = getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        Map<String, Object> out = new HashMap<>();
        out.put("paper", p.getString("paper", "A4"));
        out.put("orientation", p.getString("orientation", "auto"));
        out.put("margin", p.getInt("margin", 5));
        out.put("fontSize", p.getFloat("fontSize", 10f));
        out.put("autoFit", p.getBoolean("autoFit", true));
        out.put("repeatHeader", p.getBoolean("repeatHeader", true));
        out.put("pageNumber", p.getBoolean("pageNumber", true));
        return out;
    }

    private void printTable(Map<String, Object> data) {
        String title = str(data.get("title"));
        String subtitle = str(data.get("subtitle"));
        List<String> columns = stringList(data.get("columns"));
        List<List<String>> rows = stringRows(data.get("rows"));
        Map<String, Object> settings = map(data.get("settings"));

        String paper = strOr(settings.get("paper"), "A4");
        String orientation = strOr(settings.get("orientation"), "auto");
        int marginMm = asInt(settings.get("margin"), 5);
        float fontSize = asFloat(settings.get("fontSize"), 10f);
        boolean repeatHeader = asBool(settings.get("repeatHeader"), true);
        boolean pageNumber = asBool(settings.get("pageNumber"), true);

        boolean landscape = "landscape".equalsIgnoreCase(orientation);
        if ("auto".equalsIgnoreCase(orientation)) {
            landscape = columns.size() > 6;
        }

        PrintAttributes.MediaSize media;
        if ("A5".equalsIgnoreCase(paper)) {
            media = landscape ? PrintAttributes.MediaSize.ISO_A5.asLandscape()
                    : PrintAttributes.MediaSize.ISO_A5;
        } else if ("A3".equalsIgnoreCase(paper)) {
            media = landscape ? PrintAttributes.MediaSize.ISO_A3.asLandscape()
                    : PrintAttributes.MediaSize.ISO_A3;
        } else if ("LETTER".equalsIgnoreCase(paper)) {
            media = landscape ? PrintAttributes.MediaSize.NA_LETTER.asLandscape()
                    : PrintAttributes.MediaSize.NA_LETTER;
        } else if ("LEGAL".equalsIgnoreCase(paper)) {
            media = landscape ? PrintAttributes.MediaSize.NA_LEGAL.asLandscape()
                    : PrintAttributes.MediaSize.NA_LEGAL;
        } else {
            media = landscape ? PrintAttributes.MediaSize.ISO_A4.asLandscape()
                    : PrintAttributes.MediaSize.ISO_A4;
        }

        int marginMils = Math.max(0, marginMm) * 39;
        PrintAttributes attrs = new PrintAttributes.Builder()
                .setMediaSize(media)
                .setMinMargins(new PrintAttributes.Margins(
                        marginMils, marginMils, marginMils, marginMils))
                .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                .setResolution(new PrintAttributes.Resolution(
                        "student_comparison", "Student Comparison", 300, 300))
                .build();

        PrintManager pm = (PrintManager) getSystemService(Context.PRINT_SERVICE);
        if (pm == null) throw new IllegalStateException("Android Print service is unavailable.");

        pm.print(
                "Student Comparison - " + (title.isEmpty() ? "Report" : title),
                new StudentTablePrintAdapter(
                        title, subtitle, columns, rows, fontSize, repeatHeader, pageNumber),
                attrs
        );
    }

    private static class StudentTablePrintAdapter extends PrintDocumentAdapter {
        private final String title;
        private final String subtitle;
        private final List<String> columns;
        private final List<List<String>> rows;
        private final float fontSize;
        private final boolean repeatHeader;
        private final boolean pageNumber;
        private int pageHeight;
        private int pageWidth;
        private float rowHeight;
        private float headerHeight;

        StudentTablePrintAdapter(
                String title, String subtitle, List<String> columns, List<List<String>> rows,
                float fontSize, boolean repeatHeader, boolean pageNumber) {
            this.title = title;
            this.subtitle = subtitle;
            this.columns = columns;
            this.rows = rows;
            this.fontSize = Math.max(7f, Math.min(16f, fontSize));
            this.repeatHeader = repeatHeader;
            this.pageNumber = pageNumber;
        }

        @Override
        public void onLayout(PrintAttributes oldAttributes, PrintAttributes newAttributes,
                              CancellationSignal cancellationSignal,
                              LayoutResultCallback callback, Bundle extras) {
            if (cancellationSignal.isCanceled()) {
                callback.onLayoutCancelled();
                return;
            }
            pageWidth = Math.round(newAttributes.getMediaSize().getWidthMils() * 0.072f);
            pageHeight = Math.round(newAttributes.getMediaSize().getHeightMils() * 0.072f);
            rowHeight = Math.max(30f, fontSize * 3.0f);
            headerHeight = fontSize * 5.0f;
            int count = pageCount();
            PrintDocumentInfo info = new PrintDocumentInfo.Builder("student_comparison_report")
                    .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                    .setPageCount(count)
                    .build();
            callback.onLayoutFinished(info, true);
        }

        private int rowPages() {
            float usable = pageHeight - headerHeight - 30f;
            int perPage = Math.max(1, (int) (usable / rowHeight));
            return Math.max(1, (int) Math.ceil(rows.size() / (double) perPage));
        }

        private int pageCount() {
            // All selected columns stay together on every page.
            return rowPages();
        }

        @Override
        public void onWrite(PageRange[] pages, ParcelFileDescriptor destination,
                            CancellationSignal cancellationSignal, WriteResultCallback callback) {
            PdfDocument pdf = new PdfDocument();
            try {
                int total = pageCount();
                int rowPageCount = rowPages();
                for (int page = 0; page < total; page++) {
                    if (cancellationSignal.isCanceled()) {
                        callback.onWriteCancelled();
                        return;
                    }
                    int rowPage = page % rowPageCount;
                    PdfDocument.PageInfo info =
                            new PdfDocument.PageInfo.Builder(pageWidth, pageHeight, page + 1).create();
                    PdfDocument.Page pdfPage = pdf.startPage(info);
                    drawPage(pdfPage.getCanvas(), rowPage, rowPageCount, total, page + 1);
                    pdf.finishPage(pdfPage);
                }
                pdf.writeTo(new FileOutputStream(destination.getFileDescriptor()));
                callback.onWriteFinished(new PageRange[]{PageRange.ALL_PAGES});
            } catch (Exception e) {
                callback.onWriteFailed(e.getMessage());
            } finally {
                pdf.close();
            }
        }

        private List<Integer> allColumnIndexes() {
            List<Integer> indexes = new ArrayList<>();
            for (int i = 0; i < columns.size(); i++) {
                indexes.add(i);
            }
            return indexes;
        }

        private void drawPage(Canvas c, int rowPage, int rowPageCount,
                              int totalPages, int displayPage) {
            Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            p.setColor(android.graphics.Color.BLACK);
            p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
            p.setTextSize(fontSize);

            float left = 18f;
            float y = 18f;
            c.drawText(title, left, y, p);
            y += fontSize * 1.45f;
            p.setTypeface(Typeface.DEFAULT);
            c.drawText(subtitle, left, y, p);
            y += fontSize * 1.45f;

            int perPage = Math.max(1, (int) ((pageHeight - y - 25f) / rowHeight));
            int start = rowPage * perPage;
            int end = Math.min(rows.size(), start + perPage);

            drawTable(c, y, start, end, allColumnIndexes(),
                    rowPage == 0 || repeatHeader);

            if (pageNumber) {
                p.setTextSize(Math.max(7f, fontSize - 1f));
                c.drawText("Page " + displayPage + " of " + totalPages,
                        left, pageHeight - 10f, p);
            }
        }

        private float[] calculateColumnWidths(List<Integer> indexes, Paint p, float totalWidth) {
            final float horizontalPadding = 6f; // 3pt on each side; compact cells.
            final float minWidth = 30f;
            final float maxWidth = Math.max(60f, totalWidth * 0.28f);
            float[] widths = new float[indexes.size()];
            float desiredTotal = 0f;

            for (int i = 0; i < indexes.size(); i++) {
                int col = indexes.get(i);
                float desired = p.measureText(columns.get(col)) + horizontalPadding;

                // Use the DB/raw value widths as the basis for the column size.
                int samples = Math.min(rows.size(), 80);
                for (int r = 0; r < samples; r++) {
                    List<String> row = rows.get(r);
                    String value = col < row.size() && row.get(col) != null ? row.get(col).trim() : "";
                    if (!value.isEmpty()) {
                        float measured = p.measureText(value) + horizontalPadding;
                        desired = Math.max(desired, measured);
                    }
                }

                desired = Math.max(minWidth, Math.min(maxWidth, desired));
                if (col == 0) {
                    desired = Math.max(34f, Math.min(50f, desired));
                }
                widths[i] = desired;
                desiredTotal += desired;
            }

            if (desiredTotal <= 0f) {
                return widths;
            }

            // Keep every selected column on the same page. When there is spare
            // space, expand proportionally; when crowded, shrink proportionally.
            float scale = totalWidth / desiredTotal;
            for (int i = 0; i < widths.length; i++) {
                widths[i] *= scale;
            }

            // Never let rounding leave the table wider than the printable area.
            float actual = 0f;
            for (float w : widths) actual += w;
            if (actual > totalWidth && actual > 0f) {
                float correction = totalWidth / actual;
                for (int i = 0; i < widths.length; i++) {
                    widths[i] *= correction;
                }
            }
            return widths;
        }

        private void drawTable(Canvas c, float y, int start, int end,
                               List<Integer> indexes, boolean drawHeader) {
            Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            p.setAntiAlias(true);
            p.setTextSize(fontSize);
            p.setStrokeWidth(1f);

            float left = 18f;
            float width = pageWidth - 36f;
            int n = Math.max(1, indexes.size());
            float[] colWidths = calculateColumnWidths(indexes, p, width);

            if (drawHeader) {
                p.setStyle(Paint.Style.FILL);
                p.setColor(android.graphics.Color.rgb(235, 235, 235));
                c.drawRect(left, y, left + width, y + rowHeight, p);
                p.setColor(android.graphics.Color.BLACK);
                p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
                float x = left;
                for (int i = 0; i < n; i++) {
                    int col = indexes.get(i);
                    drawCellText(c, columns.get(col), x, y, colWidths[i], p, true);
                    x += colWidths[i];
                }
                p.setStyle(Paint.Style.STROKE);
                c.drawRect(left, y, left + width, y + rowHeight, p);
                p.setStyle(Paint.Style.FILL);
                y += rowHeight;
            }

            // Hard reset after the header: student data must never inherit bold state.
            p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.NORMAL));
            p.setFakeBoldText(false);
            for (int r = start; r < end; r++) {
                List<String> row = rows.get(r);
                p.setColor(android.graphics.Color.BLACK);
                p.setStyle(Paint.Style.STROKE);
                c.drawRect(left, y, left + width, y + rowHeight, p);

                float x = left;
                for (int i = 0; i < n; i++) {
                    c.drawLine(x, y, x, y + rowHeight, p);
                    int col = indexes.get(i);
                    drawCellText(c, col < row.size() ? row.get(col) : "",
                            x, y, colWidths[i], p, false);
                    x += colWidths[i];
                }
                c.drawLine(left + width, y, left + width, y + rowHeight, p);
                p.setStyle(Paint.Style.FILL);
                y += rowHeight;
            }
        }

        private void drawCellText(Canvas c, String text, float x, float top,
                                  float width, Paint p, boolean bold) {
            // Only column headers are bold; every student-data cell is always normal.
            p.setTypeface(Typeface.create(Typeface.DEFAULT, bold ? Typeface.BOLD : Typeface.NORMAL));
            p.setColor(android.graphics.Color.BLACK);
            p.setTextSize(fontSize);
            String value = text == null ? "" : text.trim();
            float maxWidth = Math.max(10f, width - 6f);

            if (value.isEmpty()) {
                return;
            }

            String first = value;
            String second = "";
            if (p.measureText(first) > maxWidth) {
                int count = p.breakText(first, true, maxWidth, null);
                count = Math.max(1, Math.min(count, first.length()));
                first = first.substring(0, count).trim();
                String rest = value.substring(count).trim();
                if (!rest.isEmpty()) {
                    int secondCount = p.breakText(rest, true, maxWidth - p.measureText("…"), null);
                    secondCount = Math.max(1, Math.min(secondCount, rest.length()));
                    second = rest.substring(0, secondCount).trim();
                    if (secondCount < rest.length()) second += "…";
                }
            }

            float lineHeight = fontSize * 1.15f;
            Paint.FontMetrics fm = p.getFontMetrics();
            float base1 = top + (rowHeight - lineHeight * (second.isEmpty() ? 1 : 2)) / 2f
                    - fm.ascent;
            c.drawText(first, x + 3, base1, p);
            if (!second.isEmpty()) {
                c.drawText(second, x + 3, base1 + lineHeight, p);
            }
        }
    }

    private static int asInt(Object v, int fallback) {
        try { return v == null ? fallback : Integer.parseInt(String.valueOf(v)); }
        catch (Exception e) { return fallback; }
    }
    private static float asFloat(Object v, float fallback) {
        try { return v == null ? fallback : Float.parseFloat(String.valueOf(v)); }
        catch (Exception e) { return fallback; }
    }
    private static boolean asBool(Object v, boolean fallback) {
        if (v == null) return fallback;
        return Boolean.parseBoolean(String.valueOf(v));
    }
    private static String str(Object v) { return v == null ? "" : String.valueOf(v); }
    private static String strOr(Object v, String fallback) {
        String s = str(v); return s.isEmpty() ? fallback : s;
    }
    private static Map<String, Object> map(Object v) {
        return v instanceof Map ? (Map<String, Object>) v : new HashMap<>();
    }
    private static List<String> stringList(Object v) {
        List<String> out = new ArrayList<>();
        if (v instanceof List) for (Object x : (List<?>) v) out.add(str(x));
        return out;
    }
    private static List<List<String>> stringRows(Object v) {
        List<List<String>> out = new ArrayList<>();
        if (v instanceof List) for (Object row : (List<?>) v) {
            if (row instanceof List) out.add(stringList(row));
        }
        return out;
    }
}
