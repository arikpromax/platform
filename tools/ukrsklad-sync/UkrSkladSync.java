/*
 * Обмін УкрСклад ↔ сайт (Just shop).
 *
 * Стоїть на комп'ютері з УкрСкладом. До бази підключається локально, як і
 * будь-яка утиліта для УкрСкладу, а з сайтом говорить сама по https — тож
 * базу не треба відкривати в інтернет. Кожні кілька хвилин:
 *
 *   1. забирає з сайту нові замовлення й робить на них видаткові
 *      (від одного клієнта «Інтернет-магазин»); скасування й повернення —
 *      накладною на повернення від клієнта (VZNAKL, тип документа 12);
 *   2. каже сайту, які замовлення провела (і яких не змогла — товару вже немає);
 *   3. читає в УкрСкладі залишки й ціни і шле на сайт те, що змінилось,
 *      а раз на добу — повний перелік.
 *
 * Запуск:  run.bat            — працює безперервно
 *          run.bat --once     — один прохід і вихід (для перевірки)
 *          run.bat --check    — лише перевірити зв'язок, нічого не змінює
 *
 * Java 8 і новіша. Потрібен лише драйвер Firebird (Jaybird) у теці lib.
 */

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.RandomAccessFile;
import java.io.Writer;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.channels.FileLock;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.Charset;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.Set;

public class UkrSkladSync {

    static final String VERSION = "2026-10-20";

    /* ---------- налаштування з ukrsklad-sync.ini ---------- */

    static Map<String, Map<String, String>> ini = new LinkedHashMap<String, Map<String, String>>();

    static String cfg(String section, String key, String def) {
        Map<String, String> s = ini.get(section);
        String v = s == null ? null : s.get(key);
        return v == null || v.trim().isEmpty() ? def : v.trim();
    }

    static String need(String section, String key) {
        String v = cfg(section, key, null);
        if (v == null) throw new IllegalStateException("У ukrsklad-sync.ini не заповнено [" + section + "] " + key);
        return v;
    }

    static int needInt(String section, String key) {
        String v = need(section, key);
        try {
            return Integer.parseInt(v);
        } catch (NumberFormatException e) {
            throw new IllegalStateException("У ukrsklad-sync.ini [" + section + "] " + key + " має бути числом, а не «" + v + "»");
        }
    }

    // Простий ini: [розділ], ключ = значення, рядки з # чи ; на початку — коментарі
    static void readIni(String path) throws IOException {
        String text = new String(readAll(new FileInputStream(path)), StandardCharsets.UTF_8);
        if (text.startsWith("﻿")) text = text.substring(1);
        Map<String, String> cur = null;
        for (String raw : text.split("\r?\n")) {
            String line = raw.trim();
            if (line.isEmpty() || line.startsWith("#") || line.startsWith(";")) continue;
            if (line.startsWith("[") && line.endsWith("]")) {
                cur = new LinkedHashMap<String, String>();
                ini.put(line.substring(1, line.length() - 1).trim().toLowerCase(), cur);
                continue;
            }
            int eq = line.indexOf('=');
            if (eq < 0 || cur == null) continue;
            cur.put(line.substring(0, eq).trim().toLowerCase(), line.substring(eq + 1).trim());
        }
    }

    // Значення, які читаємо один раз при старті
    static String siteUrl, siteKey, siteId;
    static int firmaId, skladId, clientId, userId;
    static boolean dry, moveStock;
    static String saleHead, saleLines, retHead, retLines, zalTable;

    static void loadSettings() {
        siteUrl = need("site", "url");
        siteKey = need("site", "key");
        siteId = need("site", "site_id");
        firmaId = needInt("ukrsklad", "firma_id");
        skladId = needInt("ukrsklad", "sklad_id");
        clientId = needInt("ukrsklad", "client_id");
        userId = needInt("ukrsklad", "doc_user_id");
        dry = "true".equalsIgnoreCase(cfg("mode", "dry", "false"));
        // залишок разом із документом (УкрСклад сам міняє його лише при «Зберегти» у вікні)
        moveStock = !"false".equalsIgnoreCase(cfg("documents", "move_stock", "true"));
        zalTable = cfg("documents", "stock_table", "TOVAR_ZAL");
        saleHead = cfg("documents", "sale_header", "VNAKL");
        saleLines = cfg("documents", "sale_lines", "VNAKL_");
        retHead = cfg("documents", "return_header", "VZNAKL");
        retLines = cfg("documents", "return_lines", "VZNAKL_");
        for (String t : Arrays.asList(saleHead, saleLines, retHead, retLines)) {
            if (t != null && !t.matches("[A-Za-z0-9_]+")) {
                throw new IllegalStateException("Назва таблиці в [documents] може містити лише латиницю, цифри й «_»: " + t);
            }
        }
    }

    /* ---------- журнал ---------- */

    static final String LOG = "ukrsklad-sync.log";
    static final DateTimeFormatter STAMP = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    // те саме попередження (напр. «товару немає») пишемо раз, а не щопроходу
    static final Set<String> told = new HashSet<String>();

    static void logOnce(String key, String msg) {
        if (told.add(key)) log(msg);
    }

    static synchronized void log(String msg) {
        String line = LocalDateTime.now().format(STAMP) + "  " + msg;
        System.out.println(line);
        try {
            File f = new File(LOG);
            if (f.length() > 5L * 1024 * 1024) {   // журнал не росте безкінечно
                File old = new File(LOG + ".old");
                old.delete();
                f.renameTo(old);
            }
            Writer w = new OutputStreamWriter(new FileOutputStream(LOG, true), StandardCharsets.UTF_8);
            try {
                w.write(line + "\r\n");
            } finally {
                w.close();
            }
        } catch (IOException ignore) {
            // журнал на диск не записався — у вікні все одно видно
        }
    }

    /* ---------- запуск ---------- */

    public static void main(String[] args) throws Exception {
        List<String> a = Arrays.asList(args);
        boolean once = a.contains("--once");
        boolean check = a.contains("--check");
        String iniPath = "ukrsklad-sync.ini";
        for (String s : args) if (!s.startsWith("--")) iniPath = s;

        // друга копія програми задвоїла б документи — не пускаємо
        RandomAccessFile lockFile = new RandomAccessFile("ukrsklad-sync.lock", "rw");
        FileLock lock = lockFile.getChannel().tryLock();
        if (lock == null) {
            System.out.println("Програма вже запущена (інше вікно чи завдання). Друга копія не потрібна.");
            return;
        }

        readIni(iniPath);
        loadSettings();
        log("Обмін УкрСклад ↔ сайт, версія " + VERSION + (dry ? " — ПРОБНИЙ РЕЖИМ: у базу нічого не пишемо" : ""));

        if (check) {
            checkAll();
            return;
        }
        int pause = Integer.parseInt(cfg("timing", "interval_sec", "120"));
        while (true) {
            try {
                cycle();
            } catch (Throwable e) {
                log("ПОМИЛКА проходу: " + e);
            }
            if (once) break;
            Thread.sleep(Math.max(30, pause) * 1000L);
        }
    }

    /* ---------- один прохід ---------- */

    static void cycle() throws Exception {
        Connection db = openDb();
        try {
            Map<String, StockRow> stock = readStock(db);
            orders(db, stock);
            // після проведених замовлень залишки в УкрСкладі змінились — читаємо ще раз
            sendStock(readStock(db));
        } finally {
            try {
                db.close();
            } catch (SQLException ignore) {
            }
        }
    }

    /* ---------- база УкрСкладу ---------- */

    static String lastDbUrl = "";

    static Connection openDb() throws Exception {
        String driver = cfg("database", "driver", "org.firebirdsql.jdbc.FBDriver");
        try {
            Class.forName(driver);
        } catch (ClassNotFoundException e) {
            throw new IllegalStateException("немає драйвера Firebird (" + driver + ") — покладіть jar-файли Jaybird у теку lib");
        }
        /* База УкрСкладу у WIN1251, тож і з'єднання відкриваємо у WIN1251: тоді
           Firebird віддає назви як є, без перекодування, і помилки «Cannot
           transliterate character between character sets» не буває (вона
           з'являється, коли з'єднання в UTF8). У UTF-8 для сайту перетворює
           вже сама Java. Кодування — і в адресі, і окремим параметром. */
        String charset = cfg("database", "db_charset", "WIN1251");
        String url = "jdbc:firebirdsql:" + cfg("database", "host", "localhost") + "/"
                + cfg("database", "db_port", "3050") + ":" + need("database", "db_path") + "?encoding=" + charset;
        Properties p = new Properties();
        p.setProperty("user", cfg("database", "user", "SYSDBA"));
        p.setProperty("password", cfg("database", "password", ""));
        p.setProperty("encoding", charset);
        lastDbUrl = url;
        Connection c = DriverManager.getConnection(url, p);
        c.setAutoCommit(false);
        return c;
    }

    static final class StockRow {
        String id, sku, size, name;
        int qty;
        double price, sale;

        String fingerprint() {
            return qty + "|" + num(price) + "|" + num(sale);
        }
    }

    /*
     * Залишки й ціни — запитом із файлу stock.sql (див. там, які колонки потрібні).
     * Запит лише читає; {SKLAD_ID} у ньому замінюється числом із налаштувань.
     */
    static Map<String, StockRow> readStock(Connection db) throws Exception {
        String file = cfg("stock", "query_file", "stock.sql");
        String sql = new String(readAll(new FileInputStream(file)), StandardCharsets.UTF_8);
        if (sql.startsWith("﻿")) sql = sql.substring(1);
        sql = sql.replace("{SKLAD_ID}", String.valueOf(skladId)).trim();
        while (sql.endsWith(";")) sql = sql.substring(0, sql.length() - 1).trim();
        if (sql.replaceAll("(?m)^\\s*--.*$", "").trim().isEmpty()) {
            throw new IllegalStateException(file + " ще не заповнений: потрібен запит, звідки брати залишки й ціни");
        }

        Map<String, StockRow> out = new LinkedHashMap<String, StockRow>();
        PreparedStatement ps = db.prepareStatement(sql);
        try {
            ResultSet rs = ps.executeQuery();
            Set<String> cols = new HashSet<String>();
            Set<String> raw = new HashSet<String>();   // колонки, які база віддає байтами (CHARACTER SET OCTETS)
            ResultSetMetaData md = rs.getMetaData();
            for (int i = 1; i <= md.getColumnCount(); i++) {
                String label = md.getColumnLabel(i).toUpperCase();
                cols.add(label);
                int t = md.getColumnType(i);
                if (t == Types.BINARY || t == Types.VARBINARY || t == Types.LONGVARBINARY) raw.add(label);
            }
            for (String c : Arrays.asList("ID", "QTY", "PRICE")) {
                if (!cols.contains(c)) throw new IllegalStateException("У stock.sql немає колонки " + c + " (є: " + cols + ")");
            }
            while (rs.next()) {
                StockRow r = new StockRow();
                r.id = str(rs.getString("ID"));
                if (r.id.isEmpty()) continue;
                r.sku = text(rs, "SKU", cols, raw);
                r.size = text(rs, "SIZE", cols, raw);
                r.name = text(rs, "NAME", cols, raw);
                r.qty = (int) Math.max(0, Math.floor(rs.getDouble("QTY") + 1e-9));
                r.price = rs.getDouble("PRICE");
                r.sale = cols.contains("SALE") ? rs.getDouble("SALE") : 0;
                out.put(r.id, r);
            }
            rs.close();
        } finally {
            ps.close();
            db.rollback();   // лише читали — транзакцію просто закриваємо
        }
        return out;
    }

    /*
     * Текст із бази. Якщо поле в базі збережене в іншому кодуванні, ніж WIN1251,
     * Firebird не може його перекласти й падає з «Cannot transliterate character
     * between character sets». Тоді в stock.sql поле віддають сирими байтами —
     * CAST(... AS VARCHAR(1000) CHARACTER SET OCTETS) — а тут ми самі розпізнаємо,
     * UTF-8 це чи WIN1251.
     */
    static String text(ResultSet rs, String col, Set<String> cols, Set<String> raw) throws SQLException {
        if (!cols.contains(col)) return "";
        if (!raw.contains(col)) return str(rs.getString(col));
        byte[] b = rs.getBytes(col);
        return b == null ? "" : decode(b).trim();
    }

    static String decode(byte[] b) {
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(b)).toString();
        } catch (CharacterCodingException notUtf8) {
            return new String(b, Charset.forName("windows-1251"));
        }
    }

    /* ---------- замовлення сайту → документи УкрСкладу ---------- */

    static void orders(Connection db, Map<String, StockRow> stock) throws Exception {
        Map<String, Object> res = obj(Json.parse(http("GET", "sync=orders", null)));
        List<Object> list = arr(res.get("orders"));
        if (list.isEmpty()) return;
        log("Замовлень із сайту: " + list.size());

        List<String> done = new ArrayList<String>();   // провели — сайт перестане їх надсилати
        List<String> shortRefs = new ArrayList<String>();   // товару вже немає — сайт попередить власника
        for (Object item : list) {
            Map<String, Object> o = obj(item);
            String ref = str(o.get("ref"));
            String status = str(o.get("status"));
            boolean isNew = Boolean.TRUE.equals(o.get("is_new"));
            try {
                if (isNew && (status.equals("new") || status.equals("shipped") || status.equals("done"))) {
                    String r = makeDoc(db, o, false, stock);
                    if (r.equals("short")) shortRefs.add(ref);
                    else if (r.equals("ok")) done.add(ref);
                } else if (!isNew && (status.equals("cancelled") || status.equals("returned"))) {
                    if (findDoc(db, saleHead, docNumber(o)) == null) {
                        // видаткову так і не зробили (напр. товару не було) — повертати нічого
                        done.add(ref);
                    } else if (retHead == null || retLines == null) {
                        logOnce("ret:" + ref, "  " + ref + ": " + status
                                + " — документ повернення ще не налаштований у [documents], чекаю");
                    } else if (makeDoc(db, o, true, stock).equals("ok")) {
                        done.add(ref);
                    }
                } else {
                    // статус змінився, але документ не потрібен (напр. «відправлено») — просто відмічаємо
                    done.add(ref);
                }
            } catch (Exception e) {
                try {
                    db.rollback();
                } catch (SQLException ignore) {
                }
                log("  ПОМИЛКА із замовленням " + ref + ": " + e.getMessage() + " — спробую на наступному проході");
            }
        }

        if (dry) {
            log("  Пробний режим: сайту не кажемо, що провели (" + done.size() + " провели б, " + shortRefs.size() + " без товару)");
            return;
        }
        if (!done.isEmpty() || !shortRefs.isEmpty()) {
            Map<String, Object> body = new LinkedHashMap<String, Object>();
            body.put("refs", done);
            body.put("short", shortRefs);
            http("POST", "sync=ack", Json.write(body));
            log("  Сайт знає: проведено " + done.size() + (shortRefs.isEmpty() ? "" : ", без товару " + shortRefs.size()));
        }
    }

    /*
     * Видаткова (або повернення) на одне замовлення — за документацією Валерія:
     * шапка з нулями → рядки → назви й одиниці з довідника → суми в шапку.
     * Номер документа: дата й час замовлення + номер замовлення на сайті. Він
     * завжди той самий для того самого замовлення, тож якщо зв'язок обірвався
     * після запису, на наступному проході документ не задвоїться.
     * Повертає "ok", "short" (товару в УкрСкладі не вистачає) або "skip".
     */
    static String makeDoc(Connection db, Map<String, Object> o, boolean isReturn, Map<String, StockRow> stock) throws Exception {
        String ref = str(o.get("ref"));
        String head = isReturn ? retHead : saleHead;
        String lines = isReturn ? retLines : saleLines;
        String nu = docNumber(o);
        String what = (isReturn ? "повернення " : "видаткова ") + nu + " (замовлення " + ref + ")";

        List<Object> raw = arr(o.get("lines"));
        if (raw.isEmpty()) {
            log("  " + ref + ": у замовленні немає рядків — пропускаю");
            return "skip";
        }
        // рядки: ID товару в УкрСкладі, кількість, ціна
        List<int[]> ids = new ArrayList<int[]>();
        List<double[]> money = new ArrayList<double[]>();
        for (Object x : raw) {
            Map<String, Object> l = obj(x);
            String id = str(l.get("id"));
            if (!id.matches("\\d+")) {
                logOnce("noid:" + ref, "  " + ref + ": товар «" + str(l.get("title")) + "» (" + str(l.get("size"))
                        + ") не зв'язаний з УкрСкладом — документ не створюю, перевірте товар");
                return "skip";
            }
            int qty = (int) Math.round(dbl(l.get("qty")));
            ids.add(new int[] {Integer.parseInt(id), qty});
            money.add(new double[] {dbl(l.get("price"))});
        }

        // уже є такий документ — значить, провели минулого разу, але сайт про це не дізнався
        if (findDoc(db, head, nu) != null) {
            log("  " + what + " уже є в УкрСкладі — лише відмічаю на сайті");
            return "ok";
        }

        // продаж: чи вистачає товару (його могли щойно продати в магазині)
        if (!isReturn && "true".equalsIgnoreCase(cfg("mode", "check_stock", "true"))) {
            for (int[] t : ids) {
                StockRow r = stock.get(String.valueOf(t[0]));
                int have = r == null ? 0 : r.qty;
                if (have < t[1]) {
                    logOnce("short:" + ref, "  " + ref + ": товару ID " + t[0] + " в УкрСкладі " + have + ", а замовили " + t[1]
                            + " — документ не створюю, сайт попередить власника. Довезуть — проведу сам");
                    return "short";
                }
            }
        }

        if (dry) {
            StringBuilder b = new StringBuilder();
            for (int i = 0; i < ids.size(); i++) {
                b.append(i == 0 ? "" : ", ").append("ID ").append(ids.get(i)[0]).append(" × ").append(ids.get(i)[1])
                        .append(" по ").append(num(money.get(i)[0]));
            }
            log("  [пробний] створив би " + what + ": " + b);
            return "ok";
        }

        /* Поля в таблицях документів різні: у видаткової (VNAKL) є «Оплачено» й
           «Списувати зі складу», у повернення (VZNAKL) — ні. Тому спершу дивимось,
           які поля є в таблиці, і заповнюємо лише наявні. */
        Set<String> hc = columns(db, head);
        Set<String> lc = columns(db, lines);
        boolean paid = Boolean.TRUE.equals(o.get("paid"));

        Ins h = new Ins(head, hc);
        h.need("FIRMA_ID", firmaId).need("NU", nu).sql("DATE_DOK", "CURRENT_DATE")
                .need("CLIENT_ID", clientId).opt("SKLAD_ID", skladId).opt("DOC_USER_ID", userId)
                .sql("CENA", "0").sql("CENA_PDV", "0").sql("CURR_CENA", "0").sql("CURR_CENA_PDV", "0")
                .opt("PAID", paid || isReturn ? 1 : 0).sql("IS_MOVE", "1");
        PreparedStatement ps = db.prepareStatement(h.text());
        try {
            h.bind(ps);
            ps.executeUpdate();
        } finally {
            ps.close();
        }
        /* Номер нового документа (NUM) шукаємо за його NU — він наш і неповторний.
           RETURNING / getGeneratedKeys у старих версіях Jaybird вимагають ще
           бібліотеку antlr-runtime, а так працює з будь-якою. Ця ж транзакція
           свій щойно вставлений рядок бачить. */
        Integer found = findDoc(db, head, nu);
        if (found == null) throw new SQLException("документ " + nu + " записався, але база не віддала його номер");
        int docId = found;

        for (int i = 0; i < ids.size(); i++) {
            double price = money.get(i)[0];
            double sum = Math.round(price * ids.get(i)[1] * 100) / 100.0;
            Ins l = new Ins(lines, lc);
            l.need("PID", docId).need("TOVAR_ID", ids.get(i)[0]).opt("SKLAD_ID", skladId)
                    .need("TOV_KOLVO", (double) ids.get(i)[1])
                    .opt("TOV_CENA", price).opt("TOV_CENA_PDV", price)
                    .opt("CURR_TOV_CENA", price).opt("CURR_TOV_CENA_PDV", price)
                    .opt("TOV_SUMA", sum).opt("CURR_TOV_SUMA", sum).sql("IS_PDV", "1");
            ps = db.prepareStatement(l.text());
            try {
                l.bind(ps);
                ps.executeUpdate();
            } finally {
                ps.close();
            }
        }

        // назви й одиниці — з довідника товарів, як радить документація УкрСкладу
        List<String> set = new ArrayList<String>();
        if (lc.contains("TOV_NAME")) set.add("TOV_NAME = (SELECT NAME FROM TOVAR_NAME WHERE NUM = " + lines + ".TOVAR_ID)");
        if (lc.contains("TOV_ED")) set.add("TOV_ED = (SELECT ED_IZM FROM TOVAR_NAME WHERE NUM = " + lines + ".TOVAR_ID)");
        if (!set.isEmpty()) exec(db, "UPDATE " + lines + " SET " + join(set) + " WHERE PID = ?", docId);

        // ім'я клієнта й суми — у шапку
        set.clear();
        int sums = 0;
        if (hc.contains("CLIENT")) set.add("CLIENT = (SELECT FIO FROM CLIENT WHERE NUM = " + head + ".CLIENT_ID)");
        for (String[] p : new String[][] {{"CENA", "TOV_SUMA"}, {"CENA_PDV", "TOV_SUMA"},
                {"CURR_CENA", "CURR_TOV_SUMA"}, {"CURR_CENA_PDV", "CURR_TOV_SUMA"}}) {
            if (hc.contains(p[0]) && lc.contains(p[1])) {
                set.add(p[0] + " = (SELECT SUM(" + p[1] + ") FROM " + lines + " WHERE PID = ?)");
                sums++;
            }
        }
        if (!set.isEmpty()) {
            int[] args = new int[sums + 1];
            Arrays.fill(args, docId);
            exec(db, "UPDATE " + head + " SET " + join(set) + " WHERE NUM = ?", args);
        }

        /* Залишок. Тригерів у базі УкрСкладу немає: TOVAR_ZAL міняє сама програма,
           коли документ зберігають кнопкою «Зберегти» (Валерій, 20.10.2026). Тож
           рухаємо його тут, в одній транзакції з документом: продаж — мінус,
           повернення — плюс. Документ і залишок записуються разом або жоден. */
        if (moveStock) {
            for (int[] t : ids) {
                int n = exec(db, "UPDATE " + zalTable + " SET KOLVO = KOLVO " + (isReturn ? "+" : "-")
                        + " ? WHERE TOVAR_ID = ? AND SKLAD_ID = ?", t[1], t[0], skladId);
                if (n == 0) {
                    log("  увага: товару ID " + t[0] + " немає в залишках складу " + skladId
                            + " — документ створено, кількість змініть в УкрСкладі вручну");
                }
            }
        }
        db.commit();

        // у цьому ж проході наступне замовлення на ту саму річ має бачити новий залишок
        for (int[] t : ids) {
            StockRow r = stock.get(String.valueOf(t[0]));
            if (r != null) r.qty = isReturn ? r.qty + t[1] : Math.max(0, r.qty - t[1]);
        }
        log("  Створено " + what + ", документ № " + docId);
        return "ok";
    }

    static String docNumber(Map<String, Object> o) {
        String ref = str(o.get("ref"));
        String when = str(o.get("created_at"));
        String stamp;
        try {
            // завжди київський час, а не пояс комп'ютера: номер того самого замовлення
            // не має змінитись, навіть якщо програму перенесуть на інший комп'ютер
            stamp = OffsetDateTime.parse(when).atZoneSameInstant(ZoneId.of("Europe/Kiev"))
                    .format(DateTimeFormatter.ofPattern("yyMMdd-HHmm"));
        } catch (Exception e) {
            stamp = LocalDate.now().format(DateTimeFormatter.ofPattern("yyMMdd")) + "-0000";
        }
        // «0710-0014» → «0014»: день і місяць уже є в даті
        String no = ref.contains("-") ? ref.substring(ref.lastIndexOf('-') + 1) : ref;
        return stamp + "-" + no;
    }

    static Integer findDoc(Connection db, String head, String nu) throws SQLException {
        PreparedStatement ps = db.prepareStatement("SELECT NUM FROM " + head + " WHERE NU = ?");
        try {
            ps.setString(1, nu);
            ResultSet rs = ps.executeQuery();
            Integer id = rs.next() ? Integer.valueOf(rs.getInt(1)) : null;
            rs.close();
            return id;
        } finally {
            ps.close();
        }
    }

    // Поля таблиці з довідника самої бази. Запам'ятовуємо, щоб не питати щоразу.
    static final Map<String, Set<String>> tableCols = new HashMap<String, Set<String>>();

    static Set<String> columns(Connection db, String table) throws SQLException {
        Set<String> c = tableCols.get(table);
        if (c != null) return c;
        c = new HashSet<String>();
        PreparedStatement ps = db.prepareStatement(
                "SELECT TRIM(RDB$FIELD_NAME) FROM RDB$RELATION_FIELDS WHERE RDB$RELATION_NAME = ?");
        try {
            ps.setString(1, table.toUpperCase());
            ResultSet rs = ps.executeQuery();
            while (rs.next()) c.add(str(rs.getString(1)).toUpperCase());
            rs.close();
        } finally {
            ps.close();
        }
        if (c.isEmpty()) throw new SQLException("у базі немає таблиці " + table);
        tableCols.put(table, c);
        return c;
    }

    // INSERT лише з тих полів, що є в таблиці. need — поле обов'язкове (немає — помилка),
    // opt — значення в параметр, sql — значення як є (CURRENT_DATE, 0, 1)
    static final class Ins {
        final String table;
        final Set<String> has;
        final List<String> names = new ArrayList<String>();
        final List<String> values = new ArrayList<String>();
        final List<Object> params = new ArrayList<Object>();

        Ins(String table, Set<String> has) {
            this.table = table;
            this.has = has;
        }

        Ins need(String col, Object v) throws SQLException {
            if (!has.contains(col)) throw new SQLException("у таблиці " + table + " немає поля " + col);
            return add(col, "?", v);
        }

        Ins opt(String col, Object v) {
            if (!has.contains(col)) {
                logOnce("col:" + table + "." + col, "  у " + table + " немає поля " + col + " — пропускаю його");
                return this;
            }
            return add(col, "?", v);
        }

        Ins sql(String col, String expr) {
            if (!has.contains(col)) {
                logOnce("col:" + table + "." + col, "  у " + table + " немає поля " + col + " — пропускаю його");
                return this;
            }
            return add(col, expr, null);
        }

        Ins add(String col, String expr, Object v) {
            names.add(col);
            values.add(expr);
            if (expr.equals("?")) params.add(v);
            return this;
        }

        String text() {
            return "INSERT INTO " + table + " (" + join(names) + ") VALUES (" + join(values) + ")";
        }

        void bind(PreparedStatement ps) throws SQLException {
            for (int i = 0; i < params.size(); i++) {
                Object v = params.get(i);
                if (v instanceof Integer) ps.setInt(i + 1, (Integer) v);
                else if (v instanceof Double) ps.setDouble(i + 1, (Double) v);
                else ps.setString(i + 1, String.valueOf(v));
            }
        }
    }

    static String join(List<String> parts) {
        StringBuilder b = new StringBuilder();
        for (String p : parts) b.append(b.length() == 0 ? "" : ", ").append(p);
        return b.toString();
    }

    // повертає, скільки рядків змінено
    static int exec(Connection db, String sql, int... args) throws SQLException {
        PreparedStatement ps = db.prepareStatement(sql);
        try {
            for (int i = 0; i < args.length; i++) ps.setInt(i + 1, args[i]);
            return ps.executeUpdate();
        } finally {
            ps.close();
        }
    }

    /* ---------- залишки й ціни → сайт ---------- */

    static final String STATE = "ukrsklad-sync.state";

    static void sendStock(Map<String, StockRow> stock) throws Exception {
        Properties sent = new Properties();   // що вже знає сайт: ID → кількість|ціна|акція
        File sf = new File(STATE);
        if (sf.exists()) {
            InputStream in = new FileInputStream(sf);
            try {
                sent.load(in);
            } finally {
                in.close();
            }
        }
        // повний перелік — раз на добу після вказаної години (і найперший запуск)
        String today = LocalDate.now().toString();
        int fullHour = Integer.parseInt(cfg("timing", "full_hour", "3"));
        boolean full = !today.equals(sent.getProperty("_full_date"))
                && (LocalDateTime.now().getHour() >= fullHour || !sf.exists());

        List<Object> items = new ArrayList<Object>();
        for (StockRow r : stock.values()) {
            if (!full && r.fingerprint().equals(sent.getProperty(r.id))) continue;
            Map<String, Object> m = new LinkedHashMap<String, Object>();
            m.put("id", r.id);
            m.put("qty", r.qty);
            m.put("price", r.price);
            m.put("sale", r.sale);
            // для нового товару сайт заведе картку — потрібні артикул, розмір і назва
            m.put("sku", r.sku);
            m.put("size", r.size);
            m.put("name", r.name);
            items.add(m);
        }
        if (items.isEmpty()) return;

        Map<String, Object> body = new LinkedHashMap<String, Object>();
        body.put("items", items);
        body.put("full", full);
        if (dry) body.put("dry", true);
        Map<String, Object> res = obj(Json.parse(http("POST", "sync=stock", Json.write(body))));
        if (!Boolean.TRUE.equals(res.get("ok"))) {
            log("Сайт не прийняв залишки: " + res.get("error") + " " + str(res.get("message")));
            return;
        }
        log((dry ? "[пробний] " : "") + (full ? "Повний перелік" : "Зміни залишків") + ": надіслано " + items.size()
                + ", прийнято " + num(dbl(res.get("accepted"))) + ", змінено на сайті " + num(dbl(res.get("changed")))
                + ", обнулено " + num(dbl(res.get("zeroed"))) + ", нових карток " + arr(res.get("created")).size());
        List<Object> problems = arr(res.get("problems"));
        for (int i = 0; i < problems.size() && i < 10; i++) log("  сайт: " + Json.write(problems.get(i)));
        if (problems.size() > 10) log("  … і ще " + (problems.size() - 10) + " зауважень");
        List<Object> conflicts = arr(res.get("conflicts"));
        if (!conflicts.isEmpty()) log("  Продано і в магазині, і на сайті: " + Json.write(conflicts) + " — власник отримав повідомлення в Telegram");

        if (dry) return;   // у пробному режимі нічого не запам'ятовуємо
        for (StockRow r : stock.values()) sent.setProperty(r.id, r.fingerprint());
        if (full) sent.setProperty("_full_date", today);
        OutputStream out = new FileOutputStream(sf);
        try {
            sent.store(out, "що вже знає сайт (ID = кількість|ціна|акція)");
        } finally {
            out.close();
        }
    }

    /* ---------- перевірка зв'язку (--check) ---------- */

    static void checkAll() {
        try {
            Connection db = openDb();
            log("База УкрСкладу: підключились (" + lastDbUrl + ")");
            Map<String, StockRow> stock = readStock(db);
            log("Залишки: прочитано " + stock.size() + " товарів");
            int n = 0;
            for (StockRow r : stock.values()) {
                if (n++ >= 5) break;
                log("  ID " + r.id + " · " + r.sku + " · " + r.size + " · " + r.name + " · " + r.qty + " шт · "
                        + num(r.price) + (r.sale > 0 ? " (акція " + num(r.sale) + ")" : ""));
            }
            db.close();
        } catch (Throwable e) {
            log("База УкрСкладу: НЕ вдалося — " + e);
        }
        try {
            Map<String, Object> res = obj(Json.parse(http("GET", "sync=orders", null)));
            log("Сайт: зв'язок є, ключ підходить, нових замовлень " + arr(res.get("orders")).size());
        } catch (Throwable e) {
            log("Сайт: НЕ вдалося — " + e.getMessage());
        }
        log("Перевірку завершено, нічого не змінено.");
    }

    /* ---------- https до сайту ---------- */

    static String http(String method, String query, String body) throws IOException {
        URL u = new URL(siteUrl + (siteUrl.contains("?") ? "&" : "?") + query + "&site=" + siteId);
        HttpURLConnection c = (HttpURLConnection) u.openConnection();
        c.setConnectTimeout(20000);
        c.setReadTimeout(90000);
        c.setRequestMethod(method);
        c.setRequestProperty("X-Sync-Key", siteKey);
        c.setRequestProperty("Accept", "application/json");
        if (body != null) {
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            c.setDoOutput(true);
            c.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            OutputStream out = c.getOutputStream();
            try {
                out.write(bytes);
            } finally {
                out.close();
            }
        }
        int code = c.getResponseCode();
        InputStream in = code >= 400 ? c.getErrorStream() : c.getInputStream();
        String text = in == null ? "" : new String(readAll(in), StandardCharsets.UTF_8);
        if (code == 401) throw new IOException("сайт не прийняв ключ обміну — перевірте [site] key");
        if (code != 200) throw new IOException("сайт відповів " + code + ": " + (text.length() > 300 ? text.substring(0, 300) : text));
        return text;
    }

    /* ---------- дрібниці ---------- */

    static byte[] readAll(InputStream in) throws IOException {
        try {
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) b.write(buf, 0, n);
            return b.toByteArray();
        } finally {
            in.close();
        }
    }

    static String str(Object v) {
        return v == null ? "" : String.valueOf(v).trim();
    }

    static double dbl(Object v) {
        if (v instanceof Number) return ((Number) v).doubleValue();
        try {
            return Double.parseDouble(str(v).replace(',', '.'));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    static String num(double d) {
        return d == Math.rint(d) ? String.valueOf((long) d) : String.valueOf(d);
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> obj(Object v) {
        if (v instanceof Map) return (Map<String, Object>) v;
        throw new IllegalArgumentException("сайт відповів не тим, що очікували: " + Json.write(v));
    }

    @SuppressWarnings("unchecked")
    static List<Object> arr(Object v) {
        return v instanceof List ? (List<Object>) v : new ArrayList<Object>();
    }

    /* ---------- маленький JSON без сторонніх бібліотек ---------- */

    static final class Json {
        final String s;
        int i;

        Json(String s) {
            this.s = s;
        }

        static Object parse(String text) {
            Json j = new Json(text);
            j.ws();
            Object v = j.value();
            j.ws();
            if (j.i != text.length()) throw j.err("зайвий текст у кінці");
            return v;
        }

        void ws() {
            while (i < s.length() && Character.isWhitespace(s.charAt(i))) i++;
        }

        boolean at(char c) {
            return i < s.length() && s.charAt(i) == c;
        }

        void expect(char c) {
            if (!at(c)) throw err("очікував «" + c + "»");
            i++;
        }

        IllegalArgumentException err(String m) {
            return new IllegalArgumentException("JSON: " + m + " (позиція " + i + ")");
        }

        Object value() {
            if (i >= s.length()) throw err("текст обірвався");
            char c = s.charAt(i);
            if (c == '{') {
                i++;
                Map<String, Object> m = new LinkedHashMap<String, Object>();
                ws();
                if (at('}')) {
                    i++;
                    return m;
                }
                while (true) {
                    ws();
                    String k = string();
                    ws();
                    expect(':');
                    ws();
                    m.put(k, value());
                    ws();
                    if (at(',')) {
                        i++;
                        continue;
                    }
                    expect('}');
                    return m;
                }
            }
            if (c == '[') {
                i++;
                List<Object> l = new ArrayList<Object>();
                ws();
                if (at(']')) {
                    i++;
                    return l;
                }
                while (true) {
                    ws();
                    l.add(value());
                    ws();
                    if (at(',')) {
                        i++;
                        continue;
                    }
                    expect(']');
                    return l;
                }
            }
            if (c == '"') return string();
            if (s.startsWith("true", i)) {
                i += 4;
                return Boolean.TRUE;
            }
            if (s.startsWith("false", i)) {
                i += 5;
                return Boolean.FALSE;
            }
            if (s.startsWith("null", i)) {
                i += 4;
                return null;
            }
            int st = i;
            while (i < s.length() && "+-0123456789.eE".indexOf(s.charAt(i)) >= 0) i++;
            if (st == i) throw err("незрозумілий символ «" + c + "»");
            return Double.valueOf(s.substring(st, i));
        }

        String string() {
            expect('"');
            StringBuilder b = new StringBuilder();
            while (true) {
                if (i >= s.length()) throw err("рядок не закрито");
                char c = s.charAt(i++);
                if (c == '"') return b.toString();
                if (c != '\\') {
                    b.append(c);
                    continue;
                }
                if (i >= s.length()) throw err("рядок не закрито");
                char e = s.charAt(i++);
                switch (e) {
                    case 'n': b.append('\n'); break;
                    case 't': b.append('\t'); break;
                    case 'r': b.append('\r'); break;
                    case 'b': b.append('\b'); break;
                    case 'f': b.append('\f'); break;
                    case 'u':
                        if (i + 4 > s.length()) throw err("обірваний \\u");
                        b.append((char) Integer.parseInt(s.substring(i, i + 4), 16));
                        i += 4;
                        break;
                    default: b.append(e);
                }
            }
        }

        static String write(Object v) {
            StringBuilder b = new StringBuilder();
            write(b, v);
            return b.toString();
        }

        static void write(StringBuilder b, Object v) {
            if (v == null) {
                b.append("null");
            } else if (v instanceof String) {
                quote(b, (String) v);
            } else if (v instanceof Boolean) {
                b.append(v);
            } else if (v instanceof Number) {
                double d = ((Number) v).doubleValue();
                if (Double.isNaN(d) || Double.isInfinite(d)) b.append("null");
                else if (d == Math.rint(d) && Math.abs(d) < 1e15) b.append((long) d);
                else b.append(d);
            } else if (v instanceof Map) {
                b.append('{');
                boolean first = true;
                for (Map.Entry<?, ?> e : ((Map<?, ?>) v).entrySet()) {
                    if (!first) b.append(',');
                    first = false;
                    quote(b, String.valueOf(e.getKey()));
                    b.append(':');
                    write(b, e.getValue());
                }
                b.append('}');
            } else if (v instanceof Collection) {
                b.append('[');
                boolean first = true;
                for (Object x : (Collection<?>) v) {
                    if (!first) b.append(',');
                    first = false;
                    write(b, x);
                }
                b.append(']');
            } else {
                quote(b, String.valueOf(v));
            }
        }

        static void quote(StringBuilder b, String s) {
            b.append('"');
            for (int k = 0; k < s.length(); k++) {
                char c = s.charAt(k);
                switch (c) {
                    case '"': b.append("\\\""); break;
                    case '\\': b.append("\\\\"); break;
                    case '\n': b.append("\\n"); break;
                    case '\r': b.append("\\r"); break;
                    case '\t': b.append("\\t"); break;
                    default:
                        if (c < 0x20) b.append(String.format("\\u%04x", (int) c));
                        else b.append(c);
                }
            }
            b.append('"');
        }
    }
}
