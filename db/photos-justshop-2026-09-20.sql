-- ============================================================
--  Just shop: фото товарів — 20.09.2026
--
--  Виконати один раз: Supabase → SQL Editor → Run.
--  Окрім фото, нічого не чіпає. Повторний запуск безпечний:
--  рядок міняється лише там, де фото ще порожнє.
--
--  ЧАСТИНА 1. Прописати 235 картинок, що вже лежать у теці сайту.
--    Підібрані за артикулом у відкритому каталозі Nike — тобто це
--    саме та річ і саме той колір, а не схожа.
--
--  ЧАСТИНА 2. Поле «Ще фото» в картці товару.
--    Досі на товар було одне фото. Тепер під ним зʼявиться список,
--    куди можна докласти другий ракурс чи деталь — на сторінці
--    товару вони стануть квадратиками під головним.
-- ============================================================

-- ---------- ЧАСТИНА 1: 235 фото ----------

update public.items i
   set image_url = v.url
  from (values
    (936, 'https://arikpromax.github.io/justshop/img/p/IB3082-001.webp'),   -- Кросівки чоловічі Gato
    (938, 'https://arikpromax.github.io/justshop/img/p/HQ4181-113.webp'),   -- Світшот Solo Swoosh Жовтий Regular Fit
    (946, 'https://arikpromax.github.io/justshop/img/p/HV1165-435.webp'),   -- Sportswear CLUB SET - Trainingsanzug
    (954, 'https://arikpromax.github.io/justshop/img/p/HF6598-010.webp'),   -- Худі чоловіча Sportswear Air Max Hoodi
    (956, 'https://arikpromax.github.io/justshop/img/p/FQ7938-100.webp'),   -- Кросівки дитячі 4 Rm Black
    (958, 'https://arikpromax.github.io/justshop/img/p/DV9821-068__DV9910-068.webp'),   -- Спортивний костюм чоловічий Pro Dri-Fi
    (960, 'https://arikpromax.github.io/justshop/img/p/HF4432-349.webp'),   -- Худі чоловіча Sportswear Tech Fleece W
    (961, 'https://arikpromax.github.io/justshop/img/p/HF4433-349.webp'),   -- Штани TECH FLEECE
    (970, 'https://arikpromax.github.io/justshop/img/p/DM6838-247.webp'),   -- Спортивний костюм чоловічий Essential 
    (975, 'https://arikpromax.github.io/justshop/img/p/DV3337-022.webp'),   -- Кросівки чоловічі Air Max DnLt Smoke G
    (979, 'https://arikpromax.github.io/justshop/img/p/DX9997-504.webp'),   -- Худі чоловіче Nba Los Angeles Lakers C
    (984, 'https://arikpromax.github.io/justshop/img/p/DM1400-010.webp'),   -- Штани чоловічі Jumpman Fleece Pant Bla
    (985, 'https://arikpromax.github.io/justshop/img/p/HM0187-100.webp'),   -- Кофта NSW SW Air Run
    (986, 'https://arikpromax.github.io/justshop/img/p/HM0189-100.webp'),   -- Штани NSW SW Air Run
    (988, 'https://arikpromax.github.io/justshop/img/p/FV7400-010.webp'),   -- Худі унісекс Sb Skate Fleece Pullover 
    (992, 'https://arikpromax.github.io/justshop/img/p/FB8189-084.webp'),   -- Парка чоловіча Storm-Fit Windrunner Pr
    (993, 'https://arikpromax.github.io/justshop/img/p/DV4329-001.webp'),   -- Бутси Tiempo Legend 10 Elite SG-Pro AC
    (1001, 'https://arikpromax.github.io/justshop/img/p/DR9609-010.webp'),   -- Парка чоловіча Sportswear Storm-Fit Wi
    (1003, 'https://arikpromax.github.io/justshop/img/p/FB8185-410.webp'),   -- Пуховик чоловічий Sf Wr Pl-Fld Hd Jkt 
    (1004, 'https://arikpromax.github.io/justshop/img/p/DQ5903-222.webp'),   -- Куртка жіноча Sportswear Storm-Fit Win
    (1014, 'https://arikpromax.github.io/justshop/img/p/DX0676-010.webp'),   -- Жилетка чоловіча Tf Club Wvn Insltd Ve
    (1015, 'https://arikpromax.github.io/justshop/img/p/FB8193-247.webp'),   -- Жилетка чоловіча Storm-Fit Windrunner 
    (1016, 'https://arikpromax.github.io/justshop/img/p/HJ3136-077__HJ3145-077.webp'),   -- Спортивний костюм чоловічий Heritageme
    (1018, 'https://arikpromax.github.io/justshop/img/p/FN6348-010.webp'),   -- Анорак чоловічий Flight Mvp Jacket Bla
    (1019, 'https://arikpromax.github.io/justshop/img/p/HJ1985-464.webp'),   -- Club Woven Blue and White Tracksuit Fo
    (1020, 'https://arikpromax.github.io/justshop/img/p/FJ2586-400.webp'),   -- Бутси Phantom Gx Ii Elite Sg-Pro Ac
    (1022, 'https://arikpromax.github.io/justshop/img/p/HM0721-001.webp'),   -- Кросівки чоловічі Air Force 1 07 Next 
    (1025, 'https://arikpromax.github.io/justshop/img/p/HM0187-011__HM0189-011.webp'),   -- Спортивний костюм чоловічий Nsw Sw Air
    (1027, 'https://arikpromax.github.io/justshop/img/p/HM0170-011.webp'),   -- Штани чоловічі M NSW SW AIR PANT WV чо
    (1028, 'https://arikpromax.github.io/justshop/img/p/HM0167-011.webp'),   -- Вітрівка чоловіча M NSW SW AIR TRACKTO
    (1029, 'https://arikpromax.github.io/justshop/img/p/DV4329-400.webp'),   -- Бутси унісекс Legend 10 Elite Sg-Pro A
    (1034, 'https://arikpromax.github.io/justshop/img/p/IB3485-001.webp'),   -- Кросівки P-6000 White/Beige
    (1040, 'https://arikpromax.github.io/justshop/img/p/HJ2322-691.webp'),   -- Flight MVP Men''s Rings T-Shirt Canyon 
    (1042, 'https://arikpromax.github.io/justshop/img/p/FB2901-710.webp'),   -- Футбольний мʼяч Flight Fa23 Yellow/Vio
    (1071, 'https://arikpromax.github.io/justshop/img/p/HM0187-068.webp'),   -- Вітрівка Чоловіча SPORTSWEAR AIR RUN G
    (1072, 'https://arikpromax.github.io/justshop/img/p/CD4373-101.webp'),   -- КРОСІВКИ ЧОЛОВІЧІ REACT VISION WHITE
    (1074, 'https://arikpromax.github.io/justshop/img/p/HV6514-065__IB6663-065.webp'),   -- Спортивний Костюм Чоловічий TECHWOVEN
    (1080, 'https://arikpromax.github.io/justshop/img/p/DV9357-371.webp'),   -- ШОРТИ ЧОЛОВІЧІ 2 W 1 DRI-FIT CHALLENGE
    (1081, 'https://arikpromax.github.io/justshop/img/p/FZ1914-368.webp'),   -- Футболка ЧОЛОВІЧА ESSENTIALS SS TEE LI
    (1082, 'https://arikpromax.github.io/justshop/img/p/FN6515-457.webp'),   -- Шорти Чоловічі ESSENTIAL STMT WSH DMND
    (1086, 'https://arikpromax.github.io/justshop/img/p/FN0799-480.webp'),   -- Max90 Men''s Long-Sleeve Basketball T-S
    (1087, 'https://arikpromax.github.io/justshop/img/p/FD1309-838.webp'),   -- Футболка M NSW TEE OS OC PK2
    (1088, 'https://arikpromax.github.io/justshop/img/p/FZ5415-100.webp'),   -- Футболка ЧОЛОВІЧА MAX90 WHITE
    (1089, 'https://arikpromax.github.io/justshop/img/p/FQ3756-100.webp'),   -- Футболка УНІСЕКС T-SHIRT SPORTSWEAR WH
    (1093, 'https://arikpromax.github.io/justshop/img/p/DO9327-001.webp'),   -- Кросівки METCON 8 BLACK
    (1096, 'https://arikpromax.github.io/justshop/img/p/DD5301-010.webp'),   -- Шорти SPORTSWEAR TECH ESSENTIALS чорні
    (1100, 'https://arikpromax.github.io/justshop/img/p/HJ0679-320.webp'),   -- Шорти Tech GX
    (1102, 'https://arikpromax.github.io/justshop/img/p/MA9041-023.webp'),   -- Сумка Чоловіча HIP BAG BLACK
    (1103, 'https://arikpromax.github.io/justshop/img/p/FZ1776-133.webp'),   -- Футболка чоловіча Q54 Ss Tee Sail Whit
    (1104, 'https://arikpromax.github.io/justshop/img/p/HJ0599-030.webp'),   -- Футболка ЧОЛОВІЧА AIR MAX T-SHIRT WHIT
    (1113, 'https://arikpromax.github.io/justshop/img/p/JM0625-001.webp'),   -- Футболка Чоловіча FLIGHT BASE T-SHIRT 
    (1116, 'https://arikpromax.github.io/justshop/img/p/FV8920-410.webp'),   -- Футболка Чоловіча PSG PHOTO BLUE
    (1117, 'https://arikpromax.github.io/justshop/img/p/FZ1993-100.webp'),   -- Футболка Чоловіча T-SHIRT WHITE
    (1120, 'https://arikpromax.github.io/justshop/img/p/FD5188-410.webp'),   -- Панама УНІСЕКС APEX BUCKET HAT BLUE
    (1121, 'https://arikpromax.github.io/justshop/img/p/AR2375-103.webp'),   -- ШОРТИ ЧОЛОВІЧІ M NSW SCE SHORT FT ALUM
    (1122, 'https://arikpromax.github.io/justshop/img/p/CD4373-006.webp'),   -- Кросівки Чоловічі REACT VISION BLACK
    (1123, 'https://arikpromax.github.io/justshop/img/p/DX1487-366.webp'),   -- ШОРТИ ЧОЛОВІЧІ DRI-FIT SPORT DIAMOND G
    (1124, 'https://arikpromax.github.io/justshop/img/p/DJ1474-609.webp'),   -- Футболка Чоловіча FPSG VOICE BEIGE
    (1127, 'https://arikpromax.github.io/justshop/img/p/FV8558-410.webp'),   -- Футболка чоловіча Psg
    (1128, 'https://arikpromax.github.io/justshop/img/p/FD1070-063.webp'),   -- Футболка PSG Tee Graphic
    (1131, 'https://arikpromax.github.io/justshop/img/p/FZ5392-237.webp'),   -- Футболка Чоловіча T-SHIRT MAX90 SPORTS
    (1132, 'https://arikpromax.github.io/justshop/img/p/CJ2242-100.webp'),   -- ПЛАТТЯ ЖІНОЧЕ W NSW ESSNTL DRESS WHITE
    (1133, 'https://arikpromax.github.io/justshop/img/p/FB5621-010.webp'),   -- Панама УНІСЕКС APEX BUCKET SB BLACK
    (1135, 'https://arikpromax.github.io/justshop/img/p/DD1887-010.webp'),   -- ШОРТИ ЧОЛОВІЧІ DRI-FIT BLACK
    (1136, 'https://arikpromax.github.io/justshop/img/p/FV0067-010.webp'),   -- Футболка чоловіча Sportswear MenS Grap
    (1137, 'https://arikpromax.github.io/justshop/img/p/HJ0576-100.webp'),   -- ЧОЛОВІЧА Футболка NSW TEE M90 FW CONNE
    (1138, 'https://arikpromax.github.io/justshop/img/p/HJ0576-010.webp'),   -- Футболка ЧОЛОВІЧА TN BLACK
    (1143, 'https://arikpromax.github.io/justshop/img/p/FQ3678-203.webp'),   -- Худі ESS FLC PO LB
    (1148, 'https://arikpromax.github.io/justshop/img/p/HJ3605-100.webp'),   -- T-shirt de fitness Dri-FIT pour homme
    (1149, 'https://arikpromax.github.io/justshop/img/p/DD7014-063.webp'),   -- ШОРТИ ЧОЛОВІЧІ SPORTSWEAR CLUB GREY
    (1150, 'https://arikpromax.github.io/justshop/img/p/FN3416-001.webp'),   -- Dunk Low Racer Blue Photon Dust
    (1152, 'https://arikpromax.github.io/justshop/img/p/FV8558-100.webp'),   -- Футболка PSG Crest M
    (1153, 'https://arikpromax.github.io/justshop/img/p/FV7306-068.webp'),   -- Штани Nike Essentials Чоловічі Woven P
    (1154, 'https://arikpromax.github.io/justshop/img/p/DX1985-010.webp'),   -- Футболка ЧОЛОВІЧА M TEE BLACK
    (1155, 'https://arikpromax.github.io/justshop/img/p/DV8414-091.webp'),   -- Майка Mens Jordan Brand Graphic Short-
    (1157, 'https://arikpromax.github.io/justshop/img/p/HF5508-100.webp'),   -- КРОСІВКИ ЧОЛОВІЧІ AIR MAX PULSE WHITE
    (1159, 'https://arikpromax.github.io/justshop/img/p/HW7151-480__HM7158-480.webp'),   -- Костюм Tech Woven синій
    (1160, 'https://arikpromax.github.io/justshop/img/p/DM6838-010.webp'),   -- СПОРТИВНИЙ Костюм ЧОЛОВІЧИЙ ESSENTIAL 
    (1161, 'https://arikpromax.github.io/justshop/img/p/HQ3746-200__HQ3747-200.webp'),   -- Sportswear Tech Fleece Windrunner
    (1162, 'https://arikpromax.github.io/justshop/img/p/HM7151-013__HM7158-060.webp'),   -- СПОРТИВНИЙ Костюм ЧОЛОВІЧИЙ TECH WOVEN
    (1163, 'https://arikpromax.github.io/justshop/img/p/HM7151-014__HM7158-014.webp'),   -- СПОРТИВНИЙ Костюм ЧОЛОВІЧИЙ TECH WOVEN
    (1165, 'https://arikpromax.github.io/justshop/img/p/HF9096-100.webp'),   -- Кросівки AIR FORCE 1 NN WHITE/BLACK
    (1167, 'https://arikpromax.github.io/justshop/img/p/FZ4353-100.webp'),   -- Air Force 1 LV8 2 GS
    (1183, 'https://arikpromax.github.io/justshop/img/p/FQ8688-600.webp'),   -- Бутси чоловічі Zm Vapor 16 Elite Sg-Pr
    (1192, 'https://arikpromax.github.io/justshop/img/p/HQ8586-010.webp'),   -- Рукавиці дитячі Psg Academy Thermafit 
    (1197, 'https://arikpromax.github.io/justshop/img/p/FZ5765-010.webp'),   -- Штани чоловічі Cargo Club Black
    (1198, 'https://arikpromax.github.io/justshop/img/p/FQ7787-361.webp'),   -- Кофта Liverpool FC 24/25 Therma-FIT Te
    (1200, 'https://arikpromax.github.io/justshop/img/p/FV8254-524.webp'),   -- Худі чоловіче Nba Los Angeles Lakers V
    (1201, 'https://arikpromax.github.io/justshop/img/p/DQ7348-010.webp'),   -- Пуховик чоловічий M J Ess Puffer Jacke
    (1202, 'https://arikpromax.github.io/justshop/img/p/FV7317-222.webp'),   -- Пуховик чоловічий Brooklyn Olive
    (1204, 'https://arikpromax.github.io/justshop/img/p/DR9605-077.webp'),   -- Куртка чоловіча Sf Wr Pl-Fld Hd Jkt Gr
    (1205, 'https://arikpromax.github.io/justshop/img/p/FB7296-063.webp'),   -- Спортивний костюм чоловічий Club Fleec
    (1214, 'https://arikpromax.github.io/justshop/img/p/IH7329-101.webp'),   -- Journey Run Білий Яскраво-малиновий Чо
    (1218, 'https://arikpromax.github.io/justshop/img/p/HV0544-010__HV0546-010.webp'),   -- Спортивний костюм чоловічий Brk Gfx Po
    (1221, 'https://arikpromax.github.io/justshop/img/p/HJ4319-001.webp'),   -- Кросівки жіночі Air Max Furiosa Black
    (1228, 'https://arikpromax.github.io/justshop/img/p/FZ5763-045.webp'),   -- ACG Dri-FIT Lightweight Gloves - Black
    (1233, 'https://arikpromax.github.io/justshop/img/p/MA9156-023.webp'),   -- Сумка Monogram Mesenger
    (1235, 'https://arikpromax.github.io/justshop/img/p/FQ7761-203.webp'),   -- SPODNIE M ESS FLC PANT LB
    (1237, 'https://arikpromax.github.io/justshop/img/p/HJ1985-011.webp'),   -- Спортивний костюм чоловічий Club Wvn T
    (1238, 'https://arikpromax.github.io/justshop/img/p/DQ7466-091__DQ7340-091.webp'),   -- Спортивний костюм чоловічий Essential 
    (1239, 'https://arikpromax.github.io/justshop/img/p/FB7296-010.webp'),   -- Спортивний костюм чоловічий Club Fleec
    (1240, 'https://arikpromax.github.io/justshop/img/p/IB2999-010__IB3003-010.webp'),   -- Спортивний костюм чоловічий Rair Flc B
    (1241, 'https://arikpromax.github.io/justshop/img/p/IB4124-034.webp'),   -- Худі чоловіче Nsw Hdy Club Bb Olive
    (1246, 'https://arikpromax.github.io/justshop/img/p/MA0986-K5X.webp'),   -- Рюкзак унісекс Jam Monogram Black
    (1253, 'https://arikpromax.github.io/justshop/img/p/DX0525-010.webp'),   -- Худі чоловіча Club Fleece+ Black
    (1254, 'https://arikpromax.github.io/justshop/img/p/FV7269-010.webp'),   -- Парка чоловіча Flight Down Parka Black
    (1255, 'https://arikpromax.github.io/justshop/img/p/FV9919-652.webp'),   -- Swoosh Men''s Dri-FIT French Terry Pull
    (1256, 'https://arikpromax.github.io/justshop/img/p/FV9946-652.webp'),   -- Men''s Dri-FIT French Terry Pullover Fi
    (1257, 'https://arikpromax.github.io/justshop/img/p/DQ7466-010__DQ7340-010.webp'),   -- Спортивний костюм чоловічий Essential 
    (1258, 'https://arikpromax.github.io/justshop/img/p/HV1165-010.webp'),   -- Спортивний костюм чоловічий Club Fleec
    (1266, 'https://arikpromax.github.io/justshop/img/p/DR9605-410.webp'),   -- Пуховик чоловічий Sf Wr Pl-Fld Hd Jkt 
    (1267, 'https://arikpromax.github.io/justshop/img/p/FQ3026-410.webp'),   -- Штани Sportswear Psg Club Jogger
    (1270, 'https://arikpromax.github.io/justshop/img/p/SX7557-100.webp'),   -- Шкарпетки унісекс Multiplier White (2 
    (1272, 'https://arikpromax.github.io/justshop/img/p/DQ6448-903.webp'),   -- Шкарпетки унісекс Everyday Plus Cush C
    (1276, 'https://arikpromax.github.io/justshop/img/p/HV1480-010.webp'),   -- Жилетка чоловіча Windrunner Black
    (1277, 'https://arikpromax.github.io/justshop/img/p/DB1571-010__DV1567-010.webp'),   -- Костюм Gfx Flc Winter Po
    (1278, 'https://arikpromax.github.io/justshop/img/p/DQ4312-063.webp'),   -- Штани чоловічі Sportswear Tech Fleece 
    (1282, 'https://arikpromax.github.io/justshop/img/p/FB2208-011.webp'),   -- Revolution 7 ''Dark Smoke Grey Dusty Ca
    (1286, 'https://arikpromax.github.io/justshop/img/p/FQ1359-400.webp'),   -- Кросівки W Air Winflo 11 GTX
    (1289, 'https://arikpromax.github.io/justshop/img/p/FN5322-355.webp'),   -- Штани чоловічі Chicago Paris Saint-Ger
    (1290, 'https://arikpromax.github.io/justshop/img/p/FV7448-010.webp'),   -- Куртка чоловіча Sherpa Black
    (1291, 'https://arikpromax.github.io/justshop/img/p/FV7450-010.webp'),   -- Штани чоловічі Flight High-Pile Fleece
    (1292, 'https://arikpromax.github.io/justshop/img/p/DQ6840-072.webp'),   -- Жіноча худі Sportswear Plush Hoodie
    (1293, 'https://arikpromax.github.io/justshop/img/p/DV4361-072.webp'),   -- Жіночі Sportswear Plush
    (1294, 'https://arikpromax.github.io/justshop/img/p/FV7281-010__FV7277-010.webp'),   -- Спортивний костюм чоловічий Brooklyn F
    (1298, 'https://arikpromax.github.io/justshop/img/p/IB7241-010__IB7243-010.webp'),   -- Спортивний костюм чоловічий Brooklyn F
    (1303, 'https://arikpromax.github.io/justshop/img/p/HM0167-025.webp'),   -- Кофта чоловіча Air Track Grey
    (1304, 'https://arikpromax.github.io/justshop/img/p/HM0170-025.webp'),   -- Штани чоловічі Air Track Grey
    (1305, 'https://arikpromax.github.io/justshop/img/p/HM0167-410.webp'),   -- Кофта Woven Tracksuit Top
    (1306, 'https://arikpromax.github.io/justshop/img/p/HM0170-410.webp'),   -- Штани Woven Tracksuit Top
    (1307, 'https://arikpromax.github.io/justshop/img/p/HM0167-060.webp'),   -- Кофта Men''s Woven Tracksuit Top
    (1308, 'https://arikpromax.github.io/justshop/img/p/HM0170-060.webp'),   -- Штани Men''s Woven Tracksuit Top
    (1311, 'https://arikpromax.github.io/justshop/img/p/FV7247-010__FV7251-010.webp'),   -- Спортивний костюм чоловічий M Flt Flc 
    (1313, 'https://arikpromax.github.io/justshop/img/p/FN7659-491.webp'),   -- Худі NOCTA NOCTA
    (1314, 'https://arikpromax.github.io/justshop/img/p/HM5764-491.webp'),   -- Штани X Nocta
    (1316, 'https://arikpromax.github.io/justshop/img/p/IH4302-012.webp'),   -- Tech Mix Men''s Track Top Grey
    (1320, 'https://arikpromax.github.io/justshop/img/p/FJ7765-113.webp'),   -- Journey Run Road Running Кросівки колі
    (1325, 'https://arikpromax.github.io/justshop/img/p/HV1194-688.webp'),   -- Рюкзак жіночий One Backpack Peach
    (1326, 'https://arikpromax.github.io/justshop/img/p/FQ1359-101.webp'),   -- Кросівки Winflo 11 Gtx White
    (1327, 'https://arikpromax.github.io/justshop/img/p/DQ0800-001.webp'),   -- Кросівки жіночі React Vision Grey
    (1329, 'https://arikpromax.github.io/justshop/img/p/FQ1359-100.webp'),   -- Кросівки жіночі Winflo 11 Gore Tex Whi
    (1330, 'https://arikpromax.github.io/justshop/img/p/FQ1359-300.webp'),   -- Winflo 11 Зручні Універсальні Бігові К
    (1336, 'https://arikpromax.github.io/justshop/img/p/FV7281-091__FV7277-091.webp'),   -- Спортивний костюм чоловічий Brooklyn F
    (1359, 'https://arikpromax.github.io/justshop/img/p/FJ7774-010__FJ7779-010.webp'),   -- Спортивний костюм чоловічий Комплект L
    (1360, 'https://arikpromax.github.io/justshop/img/p/DX0613-410.webp'),   -- Штани Club Cargo Woven Pant
    (1363, 'https://arikpromax.github.io/justshop/img/p/DR9617-084.webp'),   -- Жилетка чоловіча Storm-Fit Windrunner 
    (1376, 'https://arikpromax.github.io/justshop/img/p/DZ4498-001.webp'),   -- Кросівки Чоловічі React Vision Men''S S
    (1380, 'https://arikpromax.github.io/justshop/img/p/HV0949-114__HV0959-114.webp'),   -- Спортивний костюм чоловічий Sportswear
    (1381, 'https://arikpromax.github.io/justshop/img/p/IH4302-010__IH4303-010.webp'),   -- Спортивний костюм чоловічий Tech Fleec
    (1382, 'https://arikpromax.github.io/justshop/img/p/FV7289-010__FV7277-010.webp'),   -- Спортивний костюм чоловічий Brooklyn B
    (1385, 'https://arikpromax.github.io/justshop/img/p/FB7373-410.webp'),   -- Чоловіча жилетка Sportswear Club Prima
    (1388, 'https://arikpromax.github.io/justshop/img/p/HQ8665-010.webp'),   -- Шорти Nike DF SPRT GFX
    (1391, 'https://arikpromax.github.io/justshop/img/p/HJ0679-539.webp'),   -- Шорти чоловічі Tech Gx Blue
    (1393, 'https://arikpromax.github.io/justshop/img/p/DR3337-355.webp'),   -- Спортивний костюм чоловічий Club Lined
    (1397, 'https://arikpromax.github.io/justshop/img/p/IH4301-412.webp'),   -- Sportswear Men''s T-Shirt
    (1398, 'https://arikpromax.github.io/justshop/img/p/IH4301-012.webp'),   -- Sportswear Men''s T-Shirt
    (1400, 'https://arikpromax.github.io/justshop/img/p/FD9941-063.webp'),   -- Баскетбольна сорочка з довгим рукавом
    (1401, 'https://arikpromax.github.io/justshop/img/p/DX9958-032.webp'),   -- Brooklyn Nets Courtside Men''s NBA Max9
    (1404, 'https://arikpromax.github.io/justshop/img/p/FB7551-010.webp'),   -- Олімпійка чоловіча Repel Unlimited Bla
    (1406, 'https://arikpromax.github.io/justshop/img/p/IH4289-010.webp'),   -- Кофта
    (1407, 'https://arikpromax.github.io/justshop/img/p/IH4290-010.webp'),   -- Штани
    (1409, 'https://arikpromax.github.io/justshop/img/p/IH2537-100.webp'),   -- Flight Rare Air
    (1415, 'https://arikpromax.github.io/justshop/img/p/FJ1969-050.webp'),   -- Футболка Wordmark Tee Heather
    (1416, 'https://arikpromax.github.io/justshop/img/p/DO7392-345.webp'),   -- Футболка чоловіча Sw Premium Essential
    (1418, 'https://arikpromax.github.io/justshop/img/p/HV3411-133.webp'),   -- Футболка Nike PSG SS LOGO
    (1421, 'https://arikpromax.github.io/justshop/img/p/HV3411-060.webp'),   -- Футболка чоловіча Psg Ss Logo Grey
    (1436, 'https://arikpromax.github.io/justshop/img/p/SX7673-901.webp'),   -- Шкарпетки унісекс U Nk Everyday Cush N
    (1445, 'https://arikpromax.github.io/justshop/img/p/IB8957-010.webp'),   -- Шорти чоловічі Tech Woven Black
    (1446, 'https://arikpromax.github.io/justshop/img/p/FJ7779-091__FJ7774-091.webp'),   -- Спортивний костюм чоловічий Essentials
    (1447, 'https://arikpromax.github.io/justshop/img/p/HM7151-338.webp'),   -- Вітровка чоловіча Tech Woven Black/Gre
    (1448, 'https://arikpromax.github.io/justshop/img/p/HM8241-338.webp'),   -- Штани чоловічі Tech Woven Grey
    (1450, 'https://arikpromax.github.io/justshop/img/p/HJ0679-010.webp'),   -- Шорти чоловічі Tech Gx Black
    (1451, 'https://arikpromax.github.io/justshop/img/p/HM7151-010__HM8241-010.webp'),   -- Спортивний костюм чоловічий Tech Woven
    (1456, 'https://arikpromax.github.io/justshop/img/p/IB5673-104.webp'),   -- Футболка X NOCTA MEN''S T-SHIRT
    (1459, 'https://arikpromax.github.io/justshop/img/p/HM5762-104.webp'),   -- Худі X NOCTA MEN''S FLEECE HOODIE
    (1460, 'https://arikpromax.github.io/justshop/img/p/IH8461-355__IH8466-355.webp'),   -- Костюм Tech fleece нейлон
    (1463, 'https://arikpromax.github.io/justshop/img/p/IB8956-010.webp'),   -- Вітровка чоловіча Tech Windrunner Whit
    (1464, 'https://arikpromax.github.io/justshop/img/p/IO4757-010.webp'),   -- Джемпер Nike Phoenix
    (1467, 'https://arikpromax.github.io/justshop/img/p/FZ0945-417.webp'),   -- Sport JAM x Fédération Française de Ba
    (1468, 'https://arikpromax.github.io/justshop/img/p/FZ0949-417.webp'),   -- Sport JAM x Fédération Française de Ba
    (1470, 'https://arikpromax.github.io/justshop/img/p/FV0943-001.webp'),   -- Кросівки Sportswear P-6000 Black
    (1473, 'https://arikpromax.github.io/justshop/img/p/HF9381-001.webp'),   -- Кросівки React Vision
    (1480, 'https://arikpromax.github.io/justshop/img/p/FV7289-050__FV7277-050.webp'),   -- Спортивний костюм чоловічий Brooklyn F
    (1487, 'https://arikpromax.github.io/justshop/img/p/MA9194-023.webp'),   -- Рюкзак Jam Element Backpack 25L
    (1488, 'https://arikpromax.github.io/justshop/img/p/HM7151-014__HM8241-014.webp'),   -- Спортивний костюм чоловічий Tech Woven
    (1489, 'https://arikpromax.github.io/justshop/img/p/HV3411-133.webp'),   -- Футболка чоловіча Psg Ss Logo White
    (1491, 'https://arikpromax.github.io/justshop/img/p/HM7151-065__HM7158-065.webp'),   -- Костюм Teechfleece Grey
    (1492, 'https://arikpromax.github.io/justshop/img/p/DV7689-022.webp'),   -- Куртка чоловіча 23 Engineered Grey
    (1494, 'https://arikpromax.github.io/justshop/img/p/IO1297-216.webp'),   -- Phoenix Fleece Women''s High-Waisted Wi
    (1496, 'https://arikpromax.github.io/justshop/img/p/IM5996-068.webp'),   -- Кросівки чоловічі React Vision Grey
    (1500, 'https://arikpromax.github.io/justshop/img/p/HQ2020-100.webp'),   -- 1 LOW SE YOUTH LT OREWOOD BRN/LT MADDE
    (1501, 'https://arikpromax.github.io/justshop/img/p/HM7151-010__HM7158-010.webp'),   -- Спортивний костюм чоловічий Tech Woven
    (1510, 'https://arikpromax.github.io/justshop/img/p/FQ2767-100.webp'),   -- Кросівки P-6000 Beige
    (1514, 'https://arikpromax.github.io/justshop/img/p/SX4508-101.webp'),   -- Шкарпетки унісекс U Nk V Cush Crew (3 
    (1517, 'https://arikpromax.github.io/justshop/img/p/IH4302-412__IH4303-412.webp'),   -- Спортивний костюм чоловічий Tech Fleec
    (1522, 'https://arikpromax.github.io/justshop/img/p/DR9752-100.webp'),   -- Шкарпетки унісекс Ed Ess Crew 168 Am T
    (1523, 'https://arikpromax.github.io/justshop/img/p/FD1065-011__AO9968-010.webp'),   -- Комплект спортивний Pro WomenS Tights 
    (1526, 'https://arikpromax.github.io/justshop/img/p/HF9477-010.webp'),   -- Плаття жіноче 46054 Black
    (1533, 'https://arikpromax.github.io/justshop/img/p/SM9196-A0W.webp'),   -- Сумка унісекс Jordan Element Duffle Pi
    (1536, 'https://arikpromax.github.io/justshop/img/p/DV9359-010.webp'),   -- Шорти чоловічі Dri-Fit Challenger Blac
    (1537, 'https://arikpromax.github.io/justshop/img/p/IF2062-010.webp'),   -- Чоловічі штани M NK DF MILER WOVEN PAN
    (1538, 'https://arikpromax.github.io/justshop/img/p/BV4870-010.webp'),   -- Куртка чоловіча Essential Running Hood
    (1543, 'https://arikpromax.github.io/justshop/img/p/MA0901-023.webp'),   -- Сумка унісекс Cordura Franchise Crowsb
    (1547, 'https://arikpromax.github.io/justshop/img/p/HM7151-320.webp'),   -- Вітрівка чоловіча Tech Woven Camo
    (1550, 'https://arikpromax.github.io/justshop/img/p/IU7496-010__IU7502-010.webp'),   -- Костюм TECH WVN PRO WR FZ
    (1554, 'https://arikpromax.github.io/justshop/img/p/CV8486-100.webp'),   -- Чоловічі компресійні шорти Nike Dri-FI
    (1568, 'https://arikpromax.github.io/justshop/img/p/JM0693-023.webp'),   -- Труси чоловічі Flight Black (3 шт)
    (1570, 'https://arikpromax.github.io/justshop/img/p/FN3685-051.webp'),   -- Майка жіноча Nsw Chll Knt Cami Grey
    (1571, 'https://arikpromax.github.io/justshop/img/p/HF9524-010.webp'),   -- Футболка жіноча Chill Knit Tee Pnx Bla
    (1572, 'https://arikpromax.github.io/justshop/img/p/HF9524-100.webp'),   -- Футболка жіноча Sportswear Chill Knit 
    (1573, 'https://arikpromax.github.io/justshop/img/p/IO7994-010.webp'),   -- Shorts Sportswear Women
    (1576, 'https://arikpromax.github.io/justshop/img/p/IF0849-010.webp'),   -- Air Max Men''s Woven Jacket
    (1580, 'https://arikpromax.github.io/justshop/img/p/IQ5482-045.webp'),   -- Sportswear Graphic Back Print T-Shirt 
    (1581, 'https://arikpromax.github.io/justshop/img/p/IV0609-010.webp'),   -- Футболка M NSW TEE GFX I
    (1582, 'https://arikpromax.github.io/justshop/img/p/IV0609-100.webp'),   -- Футболка M NSW TEE GFX I
    (1584, 'https://arikpromax.github.io/justshop/img/p/IF3071-100.webp'),   -- Футболка чоловіча City Ss Crew White
    (1587, 'https://arikpromax.github.io/justshop/img/p/HQ8925-051.webp'),   -- NIKE T-SHIRT JORDAN BROOKLYN
    (1589, 'https://arikpromax.github.io/justshop/img/p/IH0526-100.webp'),   -- Sportswear Shox T-Shirt Bianca
    (1591, 'https://arikpromax.github.io/justshop/img/p/DN0001-010.webp'),   -- Лонгслів чоловічий Nocta Black
    (1593, 'https://arikpromax.github.io/justshop/img/p/DZ4504-003.webp'),   -- Кросівки чоловічі Air Max 90 Black
    (1597, 'https://arikpromax.github.io/justshop/img/p/IV0607-060.webp'),   -- Футболка чоловіча Dri-Fit Grey
    (1598, 'https://arikpromax.github.io/justshop/img/p/IB6757-050.webp'),   -- Футболка чоловіча Sport Grey
    (1604, 'https://arikpromax.github.io/justshop/img/p/MA0758-AF4.webp'),   -- Рюкзак жіночий Monogram Backpack Pink 
    (1614, 'https://arikpromax.github.io/justshop/img/p/HJ3071-010__HJ3069-011.webp'),   -- Спортивний костюм чоловічий Dri-Fit Fo
    (1618, 'https://arikpromax.github.io/justshop/img/p/IF1335-010.webp'),   -- Tech Dri-FIT Woven Color-Block Shorts 
    (1625, 'https://arikpromax.github.io/justshop/img/p/IB1895-105.webp'),   -- Кросівки для бігу чоловічі Downshifter
    (1626, 'https://arikpromax.github.io/justshop/img/p/IR6985-010.webp'),   -- Футболка ACG MEN''S DRI-FIT T-SHIRT
    (1632, 'https://arikpromax.github.io/justshop/img/p/IB1895-107.webp'),   -- Кросівки чоловічі Downshifter 14 White
    (1638, 'https://arikpromax.github.io/justshop/img/p/FB7921-060__HV0959_032.webp'),   -- Костюм Sportswear Tech Fleece Windrunn
    (1639, 'https://arikpromax.github.io/justshop/img/p/IH4302-100__IH4303-491.webp'),   -- Спортивний костюм чоловічий Tech Blue
    (1642, 'https://arikpromax.github.io/justshop/img/p/IO1908-010.webp'),   -- Кросівки чоловічі Air Max 90 Drift Bla
    (1644, 'https://arikpromax.github.io/justshop/img/p/IO3152-010__IO3153-010.webp'),   -- Костюм Air Max Woven Men''s Track Pants
    (1645, 'https://arikpromax.github.io/justshop/img/p/IB3003-673__IB2999-673.webp'),   -- Спортивний костюм чоловічий Rare Air F
    (1648, 'https://arikpromax.github.io/justshop/img/p/AC4377-082.webp'),   -- Рукавиці Tech Women''s Lightweight Runn
    (1650, 'https://arikpromax.github.io/justshop/img/p/FV7317-010.webp')   -- Пуховик чоловічий Brooklyn Black
) as v(id, url)
 where i.id = v.id
   and i.site_id = 106
   and coalesce(i.image_url, '') = '';

-- ---------- ЧАСТИНА 2: поле «Ще фото» ----------
-- «Фото» стоїть у картці останнім, тож нове поле дописуємо в кінець —
-- воно опиниться одразу під ним.

update public.sites s
   set config = jsonb_set(config, '{collections}', (
     select jsonb_agg(
       case
         when c->>'key' = 'products'
          and not (c->'fields' @> '[{"key":"photos"}]'::jsonb)
         then jsonb_set(c, '{fields}',
                (c->'fields') || jsonb_build_array(jsonb_build_object(
                  'type',  'images',
                  'key',   'photos',
                  'name',  'Ще фото',
                  'extra', true,
                  'hint',  'Другий ракурс, деталь тканини, бірка, коробка. На сторінці товару вони стануть квадратиками під головним фото — покупець клікає й дивиться. Головним лишається фото вище, саме воно йде на плитку в каталозі.')))
         else c
       end)
     from jsonb_array_elements(config->'collections') c))
 where s.slug = 'justshop';

-- ---------- Перевірка ----------

select count(*) filter (where coalesce(image_url, '') <> '') as "товарів із фото",
       count(*)                                              as "усього"
  from public.items where site_id = 106 and collection = 'products';
