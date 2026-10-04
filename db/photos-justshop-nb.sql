-- Just shop: фото New Balance з офіційного сервера New Balance (04.10.2026).
--
-- 8 кросівок New Balance мали по одному фото. Тепер по 5 ракурсів з
-- nb.scene7.com (власний сервер знімків New Balance): бік, другий бік, згори,
-- пара під кутом, підошва — на білому тлі. Для NDM2002RBK у таблиці описка,
-- справжній артикул M2002RBK.
--
-- Виконати ПІСЛЯ того, як фото опубліковані на сайті.

do $nb$
declare
  p jsonb := $json$[{"id":1483,"photos":["https://arikpromax.github.io/justshop/img/n/U200210D-1.webp","https://arikpromax.github.io/justshop/img/n/U200210D-2.webp","https://arikpromax.github.io/justshop/img/n/U200210D-3.webp","https://arikpromax.github.io/justshop/img/n/U200210D-4.webp","https://arikpromax.github.io/justshop/img/n/U200210D-5.webp"]},{"id":1032,"photos":["https://arikpromax.github.io/justshop/img/n/U1906RCH-1.webp","https://arikpromax.github.io/justshop/img/n/U1906RCH-2.webp","https://arikpromax.github.io/justshop/img/n/U1906RCH-3.webp","https://arikpromax.github.io/justshop/img/n/U1906RCH-4.webp","https://arikpromax.github.io/justshop/img/n/U1906RCH-5.webp"]},{"id":1484,"photos":["https://arikpromax.github.io/justshop/img/n/M1906RLB-1.webp","https://arikpromax.github.io/justshop/img/n/M1906RLB-2.webp","https://arikpromax.github.io/justshop/img/n/M1906RLB-3.webp","https://arikpromax.github.io/justshop/img/n/M1906RLB-4.webp","https://arikpromax.github.io/justshop/img/n/M1906RLB-5.webp"]},{"id":1462,"photos":["https://arikpromax.github.io/justshop/img/n/U740CW2-1.webp","https://arikpromax.github.io/justshop/img/n/U740CW2-2.webp","https://arikpromax.github.io/justshop/img/n/U740CW2-3.webp","https://arikpromax.github.io/justshop/img/n/U740CW2-4.webp","https://arikpromax.github.io/justshop/img/n/U740CW2-5.webp"]},{"id":1485,"photos":["https://arikpromax.github.io/justshop/img/n/U20022RT-1.webp","https://arikpromax.github.io/justshop/img/n/U20022RT-2.webp","https://arikpromax.github.io/justshop/img/n/U20022RT-3.webp","https://arikpromax.github.io/justshop/img/n/U20022RT-4.webp","https://arikpromax.github.io/justshop/img/n/U20022RT-5.webp"]},{"id":948,"photos":["https://arikpromax.github.io/justshop/img/n/GC1000SB-1.webp","https://arikpromax.github.io/justshop/img/n/GC1000SB-2.webp","https://arikpromax.github.io/justshop/img/n/GC1000SB-3.webp","https://arikpromax.github.io/justshop/img/n/GC1000SB-4.webp","https://arikpromax.github.io/justshop/img/n/GC1000SB-5.webp"]},{"id":949,"photos":["https://arikpromax.github.io/justshop/img/n/GC1000SP-1.webp","https://arikpromax.github.io/justshop/img/n/GC1000SP-2.webp","https://arikpromax.github.io/justshop/img/n/GC1000SP-3.webp","https://arikpromax.github.io/justshop/img/n/GC1000SP-4.webp","https://arikpromax.github.io/justshop/img/n/GC1000SP-5.webp"]},{"id":1378,"photos":["https://arikpromax.github.io/justshop/img/n/NDM2002RBK-1.webp","https://arikpromax.github.io/justshop/img/n/NDM2002RBK-2.webp","https://arikpromax.github.io/justshop/img/n/NDM2002RBK-3.webp","https://arikpromax.github.io/justshop/img/n/NDM2002RBK-4.webp","https://arikpromax.github.io/justshop/img/n/NDM2002RBK-5.webp"]}]$json$::jsonb;
  u jsonb;
begin
  for u in select * from jsonb_array_elements(p) loop
    update items set extra = jsonb_set(extra, '{photos}', u->'photos')
     where id = (u->>'id')::bigint and site_id = 106;
  end loop;
end
$nb$;

select title as товар, jsonb_array_length(extra->'photos') as фото
  from items where id = any(array[1483,1032,1484,1462,1485,948,949,1378]) order by title;
