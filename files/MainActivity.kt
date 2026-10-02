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
                        default:
                            result.notImplemented();
                    }
                });
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
            media = landscape ? PrintAttributes.MediaSize.ISO_A5.rotate()
                    : PrintAttributes.MediaSize.ISO_A5;
        } else if ("A3".equalsIgnoreCase(paper)) {
            media = landscape ? PrintAttributes.MediaSize.ISO_A3.rotate()
                    : PrintAttributes.MediaSize.ISO_A3;
        } else if ("LETTER".equalsIgnoreCase(paper)) {
            media = landscape ? PrintAttributes.MediaSize.NA_LETTER.rotate()
                    : PrintAttributes.MediaSize.NA_LETTER;
        } else if ("LEGAL".equalsIgnoreCase(paper)) {
            media = landscape ? PrintAttributes.MediaSize.NA_LEGAL.rotate()
                    : PrintAttributes.MediaSize.NA_LEGAL;
        } else {
            media = landscape ? PrintAttributes.MediaSize.ISO_A4.rotate()
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
            this.fontSize = Math.max(7f, Math.min(18f, fontSize));
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
            pageWidth = newAttributes.getMediaSize().getWidthMils();
            pageHeight = newAttributes.getMediaSize().getHeightMils();
            rowHeight = Math.max(24f, fontSize * 2.4f);
            headerHeight = fontSize * 5.2f;
            int count = pageCount();
            PrintDocumentInfo info = new PrintDocumentInfo.Builder("student_comparison_report")
                    .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                    .setPageCount(count)
                    .build();
            callback.onLayoutFinished(info, true);
        }

        private int pageCount() {
            float usable = pageHeight - 30f;
            float first = Math.max(80f, usable - headerHeight);
            int firstRows = Math.max(1, (int) (first / rowHeight));
            if (rows.isEmpty()) return 1;
            int remaining = Math.max(0, rows.size() - firstRows);
            int perPage = Math.max(1, (int) (usable / rowHeight));
            return 1 + (int) Math.ceil(remaining / (double) perPage);
        }

        @Override
        public void onWrite(PageRange[] pages, ParcelFileDescriptor destination,
                            CancellationSignal cancellationSignal, WriteResultCallback callback) {
            PdfDocument pdf = new PdfDocument();
            try {
                int total = pageCount();
                for (int page = 0; page < total; page++) {
                    if (cancellationSignal.isCanceled()) {
                        callback.onWriteCancelled();
                        return;
                    }
                    PdfDocument.PageInfo info =
                            new PdfDocument.PageInfo.Builder(pageWidthPoints(), pageHeightPoints(), page + 1).create();
                    PdfDocument.Page pdfPage = pdf.startPage(info);
                    drawPage(pdfPage.getCanvas(), page, total);
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

        private int pageWidthPoints() { return Math.max(1, Math.round(pageWidth * 0.072f)); }
        private int pageHeightPoints() { return Math.max(1, Math.round(pageHeight * 0.072f)); }

        private void drawPage(Canvas c, int page, int totalPages) {
            Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            p.setColor(android.graphics.Color.BLACK);
            p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.NORMAL));

            float left = 18f;
            float right = pageWidth - 18f;
            float y = 24f;

            p.setTextSize(fontSize * 1.25f);
            p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
            c.drawText(title, left, y, p);
            y += fontSize * 1.7f;

            p.setTextSize(fontSize);
            c.drawText(subtitle, left, y, p);
            y += fontSize * 1.8f;

            int start;
            int end;
            if (page == 0) {
                start = 0;
                int capacity = Math.max(1, (int) ((pageHeight - y - 35f) / rowHeight));
                end = Math.min(rows.size(), capacity);
            } else {
                int firstCapacity = Math.max(1, (int) ((pageHeight - headerHeight - 35f) / rowHeight));
                int normalCapacity = Math.max(1, (int) ((pageHeight - 35f) / rowHeight));
                start = firstCapacity + (page - 1) * normalCapacity;
                end = Math.min(rows.size(), start + normalCapacity);
                y = 24f;
            }

            drawTable(c, y, start, end, page > 0 && repeatHeader);

            if (pageNumber) {
                p.setTypeface(Typeface.DEFAULT);
                p.setTextSize(Math.max(7f, fontSize - 1f));
                c.drawText("Page " + (page + 1) + " of " + totalPages,
                        left, pageHeight - 10f, p);
            }
        }

        private void drawTable(Canvas c, float y, int start, int end, boolean repeat) {
            Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
            p.setColor(android.graphics.Color.BLACK);
            p.setTextSize(fontSize);
            p.setStrokeWidth(1f);

            float left = 18f;
            float width = pageWidth - 36f;
            int n = Math.max(1, columns.size());
            float colW = width / n;

            if (repeat || start == 0) {
                p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
                c.drawRect(left, y - rowHeight + 3, left + width, y + 3, p);
                p.setColor(android.graphics.Color.WHITE);
                for (int i = 0; i < n; i++) {
                    drawCellText(c, columns.get(i), left + i * colW, y, colW, p, true);
                }
                p.setColor(android.graphics.Color.BLACK);
                p.setStyle(Paint.Style.STROKE);
                c.drawRect(left, y - rowHeight + 3, left + width, y + 3, p);
                p.setStyle(Paint.Style.FILL);
                y += rowHeight;
            }

            p.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.NORMAL));
            for (int r = start; r < end; r++) {
                List<String> row = rows.get(r);
                p.setColor(android.graphics.Color.BLACK);
                p.setStyle(Paint.Style.STROKE);
                c.drawRect(left, y - rowHeight + 3, left + width, y + 3, p);
                for (int i = 0; i < n; i++) {
                    float x = left + i * colW;
                    c.drawLine(x, y - rowHeight + 3, x, y + 3, p);
                    drawCellText(c, i < row.size() ? row.get(i) : "", x, y, colW, p, false);
                }
                p.setStyle(Paint.Style.FILL);
                y += rowHeight;
            }
        }

        private void drawCellText(Canvas c, String text, float x, float baseline,
                                  float width, Paint p, boolean bold) {
            p.setTypeface(Typeface.create(Typeface.DEFAULT, bold ? Typeface.BOLD : Typeface.NORMAL));
            p.setColor(bold ? android.graphics.Color.WHITE : android.graphics.Color.BLACK);
            p.setTextSize(fontSize);
            String value = text == null ? "" : text;
            while (p.measureText(value) > width - 8 && value.length() > 1) {
                value = value.substring(0, value.length() - 1);
            }
            if (!value.equals(text) && value.length() > 1) value = value.substring(0, value.length() - 1) + "…";
            c.drawText(value, x + 4, baseline - 7, p);
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
