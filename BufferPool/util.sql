DROP FUNCTION IF EXISTS ShowHeap;
CREATE FUNCTION ShowHeap(tname text, pageNo int) RETURNS TABLE(lp text,  lp_off text, lp_flags text, lp_len text, t_xmin text, t_xmax text, t_field3 text, t_ctid text, t_hoff text, t_bits text, t_oid text,combined_flags text, raw_flags text) 
    AS $$    
        SELECT lp,  lp_off, lp_flags, lp_len, t_xmin, t_xmax, t_field3,t_ctid, t_hoff, t_bits, t_oid, combined_flags, raw_flags
        FROM heap_page_items(get_raw_page(tname, pageNo)), LATERAL heap_tuple_infomask_flags(t_infomask, t_infomask2)
        WHERE t_infomask IS NOT NULL OR t_infomask2 IS NOT NULL; 
    $$
LANGUAGE SQL;