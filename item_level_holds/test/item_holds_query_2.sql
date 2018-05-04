DROP TABLE IF EXISTS temp_item_lvl_holds;
CREATE TEMP TABLE temp_item_lvl_holds AS
SELECT
h.id,
(
    SELECT
    string_agg(v.field_content, ', ' order by v.occ_num)
    FROM
    sierra_view.varfield as v
    WHERE
    v.record_id = r.id
    AND v.varfield_type_code = 'b'
) as item_barcodes,
(
    SELECT
    string_agg(v.field_content, ', ' order by v.occ_num)
    FROM
    sierra_view.varfield as v
    WHERE
    v.record_id = h.patron_record_id
    AND v.varfield_type_code = 'b'
) as patron_barcodes,
pr.ptype_code::int as ptype,
-- l.*,
-- r.id,
r.record_type_code || r.record_num || 'a' as item_record_num,
i.item_status_code,
c.checkout_gmt,
c.loanrule_code_num,
vr.record_type_code || vr.record_num || 'a' as vol_record_num,
br.record_type_code || br.record_num || 'a' as bib_record_num,
v.field_content as volume_number,
h.placed_gmt,
pn.last_name || ', ' || pn.first_name || coalesce (' ' || NULLIF(pn.middle_name, ''), '') as full_name,
h.pickup_location_code,
-- vr.id,
p.best_title,
p.best_author
-- i.item_status_code,
-- date_part('day', NOW()::timestamp - c.checkout_gmt::timestamp) as days_checked_out,
-- h.*

FROM
sierra_view.hold as h

-- this join will exclude anything that isn't a item level hold
JOIN
sierra_view.record_metadata as r
ON
  (r.id = h.record_id)
  AND (r.record_type_code || r.campus_code = 'i')

JOIN
sierra_view.item_record as i
ON
  i.record_id = r.id

LEFT OUTER JOIN
sierra_view.checkout as c
ON
  c.item_record_id = r.id

LEFT OUTER JOIN
sierra_view.phrase_entry as e
ON
  e.record_id = r.id
  AND e.index_tag = 'b'

LEFT OUTER JOIN
sierra_view.volume_record_item_record_link as l
ON
  l.item_record_id = r.id

LEFT OUTER JOIN
sierra_view.record_metadata as vr
ON
  vr.id = l.volume_record_id

LEFT OUTER JOIN
sierra_view.varfield AS v
ON
  (v.record_id = vr.id) AND (v.varfield_type_code = 'v')

LEFT OUTER JOIN
sierra_view.bib_record_item_record_link as bl
ON
  bl.item_record_id = r.id

LEFT OUTER JOIN
sierra_view.record_metadata as br
ON
  br.id = bl.bib_record_id

LEFT OUTER JOIN
sierra_view.bib_record_property as p
ON
  p.bib_record_id = br.id

LEFT OUTER JOIN
sierra_view.patron_record as pr
ON
  pr.record_id = h.patron_record_id

LEFT OUTER JOIN
sierra_view.patron_record_fullname as pn
ON
  pn.patron_record_id = h.patron_record_id


WHERE
-- item is not a circulating/active item OR item is checked out
(
    i.item_status_code NOT IN ('t', '!', '(') -- might need to include status '-' here as well
    OR (
        i.item_status_code = '-'
        AND c.checkout_gmt IS NOT NULL
    )
)
-- item is on shelf not checked out
OR (
    i.item_status_code = '-'
    AND c.checkout_gmt IS NULL
);  
---


---
-- create the table of item level holds on shelf not checked out
DROP TABLE IF EXISTS temp_item_lvl_holds_on_shelf;
CREATE TEMP TABLE temp_item_lvl_holds_on_shelf AS
SELECT
*

FROM
temp_item_lvl_holds as i

WHERE
-- item is on shelf
(
    i.item_status_code = '-'
    AND i.checkout_gmt IS NULL
);
---


---
-- remove the on shelf not checked out holds
DELETE FROM
temp_item_lvl_holds as h

WHERE h.id IN(
	SELECT
	t.id

	FROM
	temp_item_lvl_holds_on_shelf as t
)
;
---


---
-- create the table of item level holds where item is not circulating / item checked out
DROP TABLE IF EXISTS temp_item_lvl_holds_non_or_circ_checked_out;
CREATE TEMP TABLE temp_item_lvl_holds_non_or_circ_checked_out AS
SELECT 
*

FROM
temp_item_lvl_holds as i

WHERE
(
    i.item_status_code NOT IN ('t', '!', '(') -- might need to include status '-' here as well
    OR (
        i.item_status_code = '-'
        AND i.checkout_gmt IS NOT NULL
    )
);
---


---
-- we shouldn't need to do this, since the temp_item_lvl_holds table should now be empty if the query was correct
DELETE FROM
temp_item_lvl_holds as h

WHERE h.id IN(
	SELECT
	t.id

	FROM
	temp_item_lvl_holds_non_or_circ_checked_out as t
);
---


--- 
-- These are the two queries for output
--- 
-- query 1: 
SELECT 
*

FROM
temp_item_lvl_holds_non_or_circ_checked_out as t

ORDER BY
t.ptype
;
---


-- query 2
SELECT
*

FROM
temp_item_lvl_holds_on_shelf as t

ORDER BY
t.ptype
;