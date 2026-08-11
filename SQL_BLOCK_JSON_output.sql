SET serveroutput ON;
DECLARE
  v_mapping_id                   NUMBER :=5;
  v_mapping_name                 VARCHAR(100);
  v_iter_map_comp                NUMBER :=0;
  v_iter_map_comp_connpoint      NUMBER :=0;
  v_iter_map_connections         NUMBER :=0;
  v_iter_stg_category            NUMBER :=0;
  v_iter_map_expr                NUMBER :=0;
  v_iter_map_attr                NUMBER :=0;
  v_iter_map_ref                 NUMBER :=0;
  v_iter_col                     NUMBER :=0;
  v_iter_map_prop_name           NUMBER :=0;
  v_iter_map_transformation_expr NUMBER :=0;
  v_iter_pre_successor           NUMBER :=0;
  -- CURSOR FOR MAPPING
  CURSOR c_snp_mapping
  IS
    SELECT I_Mapping,
      name AS mapping_name
    FROM prod_odi_repo.snp_mapping
    WHERE I_mapping = v_mapping_id;
  -- CURSOR FOR MAPPING COMPONENTS
  CURSOR c_snp_map_comp (p_mapping_id NUMBER)
  IS
    SELECT i_map_comp,
      name AS component_name,
      i_owner_map_comp,
      i_owner_mapping,
      type_name,
      I_map_ref,
      is_derived_name
    FROM prod_odi_repo.snp_map_comp
    WHERE i_owner_mapping= p_mapping_id;
  --CURSOR FOR MAPPING CONNECTIONS i.e. LINKS
  CURSOR c_snp_map_connections (p_mapping_id NUMBER)
  IS
    SELECT i_map_conn,
      name AS connection_link_name,
      business_name,
      i_start_map_cp,
      i_end_map_cp,
      i_owner_mapping
    FROM prod_odi_repo.snp_map_conn
    WHERE i_owner_mapping = p_mapping_id;
  -- CURSOR FOR MAPPING COMPONENT CONNECTION POINTS
  CURSOR c_snp_map_connpoint ( --p_map_comp NUMBER,
    p_start_map_cp NUMBER, p_end_map_cp NUMBER )
  IS
    SELECT I_map_cp,
      name AS connpoint_name,
      business_name,
      i_owner_map_comp,
      direction,
      cardinality,
      i_map_ref,
      i_map_cp_role,
      cp_order,
      COUNT(*) OVER(PARTITION BY i_owner_map_comp ORDER BY i_owner_map_comp) AS NO_OF_DIRECTIONS
    FROM prod_odi_repo.snp_map_cp
    WHERE --i_owner_map_comp=p_map_comp
      -- AND
      (I_map_cp =p_start_map_cp
    OR I_map_cp = p_end_map_cp) ;
  CURSOR c_map_cp_stg_category (p_mapping_id NUMBER, p_map_comp NUMBER)
  IS
    SELECT I_map_cp,
      name AS connpoint_name,
      business_name,
      i_owner_map_comp,
      direction,
      cardinality,
      i_map_ref,
      i_map_cp_role,
      cp_order,
      COUNT(*) OVER(PARTITION BY i_owner_map_comp ORDER BY i_owner_map_comp) AS NO_OF_DIRECTIONS
    FROM prod_odi_repo.snp_map_cp
    WHERE i_owner_map_comp=p_map_comp
    AND i_map_cp         IN
      (SELECT I_start_map_cp
      FROM prod_odi_repo.snp_map_conn
      WHERE i_owner_mapping=p_mapping_id
    
    UNION
    
    SELECT I_end_map_cp
    FROM prod_odi_repo.snp_map_conn
    WHERE i_owner_mapping=p_mapping_id
      )
    AND i_owner_map_comp IN
      (SELECT DISTINCT i_map_comp
      FROM prod_odi_repo.snp_map_comp
      WHERE i_owner_mapping=p_mapping_id
      ) ;
    CURSOR c_snp_map_expr (p_map_cp NUMBER)
    IS
      SELECT i_map_expr,
        is_parsed,
        i_map_cp,
        I_owner_map_prop,
        i_owner_map_attr,
        txt,
        dbms_lob.substr(txt,4000,1) AS txt_clob,
        parsed_txt,
        text_only
      FROM prod_odi_repo.snp_map_expr
      WHERE i_map_cp = p_map_cp;
    CURSOR c_snp_map_attr (p_map_cp NUMBER)
    IS
      SELECT i_map_attr,
        name AS attr_name,
        business_name,
        i_owner_map_cp,
        i_map_ref,
        attr_type,
        LENGTH AS column_attr_length,
        is_required,
        sort_pos,
        is_derived_name,
        i_data_map_ref
      FROM prod_odi_repo.snp_map_attr
      WHERE i_owner_map_cp = p_map_cp;
    CURSOR c_snp_map_ref (p_map_ref NUMBER)
    IS
      SELECT i_map_ref,
        i_owner_mapping,
        qualified_name,
        i_ref_id,
        SUBSTR(qualified_name,1,instr(qualified_name,'.')-1)                                                                                     AS cod_mod ,
        SUBSTR(qualified_name,instr(qualified_name,'.')  +1,LENGTH(qualified_name)-LENGTH(SUBSTR(qualified_name,1,instr(qualified_name,'.')))+1) AS table_name
      FROM prod_odi_repo.snp_map_ref
      WHERE i_map_ref =p_map_ref ;
    CURSOR c_snp_col (p_table_name VARCHAR2)
    IS
      SELECT I_COL,
        I_table,
        col_name,
        col_heading,
        col_desc,
        source_dt,
        pos,
        longc,
        scalec,
        file_pos,
        bytes,
        col_mandatory,
        check_flow ,
        check_stat
      FROM PROD_ODI_REPO.SNP_COL
      WHERE I_TABLE IN
        (SELECT I_TABLE
        FROM prod_odi_repo.snp_table
        WHERE (table_name= p_table_name
        OR RES_NAME      = p_table_name
        OR TABLE_ALIAS   = p_table_name)
        );
    CURSOR c_snp_map_prop_name (p_map_comp NUMBER)
    IS
      SELECT i_map_prop,
        name AS prop_name,
        business_name,
        i_prop_def,
        i_owner_mapping,
        disp_name_key,
        I_map_comp
      FROM prod_odi_repo.snp_map_prop
      WHERE i_map_comp = p_map_comp
      AND I_map_prop  IN
        (SELECT i_owner_map_prop
        FROM prod_odi_repo.snp_map_expr
        WHERE txt IS NOT NULL
        );--there should be an expression
    CURSOR c_snp_map_transformation_expr (p_map_prop NUMBER)
    IS
      SELECT i_map_expr,
        is_parsed,
        i_map_cp,
        I_owner_map_prop,
        i_owner_map_attr,
        txt,
        dbms_lob.substr(txt,4000,1) AS txt_clob,
        parsed_txt,
        text_only
      FROM prod_odi_repo.snp_map_expr
      WHERE i_owner_map_prop = p_map_prop;
    CURSOR c_snp_pre_successor (p_mapping_id NUMBER, p_map_comp NUMBER)
    IS
      SELECT conn_relation.i_map_comp ,
        conn_relation.comp_name ,
        conn_relation.type_name ,
        CASE
          WHEN conn_relation.fetch_predecessor=1
          AND predecessor_comp.FLG            ='Y'
          THEN conn_relation.predecessor_stage
        END AS predecessor_map_comp ,
        CASE
          WHEN conn_relation.fetch_predecessor=1
          AND predecessor_comp.FLG            ='Y'
          THEN predecessor_comp.component_name
        END AS predecessor_map_comp_name ,
        CASE
          WHEN conn_relation.fetch_predecessor=1
          AND predecessor_comp.FLG            ='Y'
          THEN predecessor_comp.oracle_component_type
        END AS predecessor_oracle_comp_type ,
        CASE
          WHEN conn_relation.fetch_predecessor=1
          AND predecessor_comp.FLG            ='Y'
          THEN conn_relation.predecessor_link_order
        END AS predecessor_link_order ,
        CASE
          WHEN conn_relation.fetch_successor=1
          AND successor_comp.FLG            ='Y'
          THEN conn_relation.successor_stage
        END AS successor_map_comp ,
        CASE
          WHEN conn_relation.fetch_successor=1
          AND successor_comp.FLG            ='Y'
          THEN successor_comp.component_name
        END AS successor_map_comp_name ,
        CASE
          WHEN conn_relation.fetch_successor=1
          AND successor_comp.FLG            ='Y'
          THEN successor_comp.oracle_component_type
        END AS successor_oracle_comp_type ,
        CASE
          WHEN conn_relation.fetch_successor=1
          AND successor_comp.FLG            ='Y'
          THEN conn_relation.successor_link_order
        END AS successor_link_order
      FROM
        (SELECT conn.i_map_conn ,
          conn.name AS conn_name ,
          conn.business_name ,
          conn.i_start_map_cp ,
          conn.i_end_map_cp ,
          conn.i_owner_mapping ,
          src_cp.i_map_cp AS src_map_cp ,
          tgt_cp.i_map_cp AS tgt_map_cp
          --, src_cp.name as src_cp_name
          ,
          src_cp.i_owner_map_comp AS src_comp_id ,
          tgt_cp.i_owner_map_comp AS tgt_comp_id ,
          src_cp.direction        AS src_direction ,
          tgt_cp.direction        AS tgt_direction
          --            , src_cp.cardinality
          -- , src_cp.cp_order as src_link_order
          --, tgt_cp.name as tgt_cp_name
          --            , tgt_cp.cardinality
          -- , tgt_cp.cp_order as tgt_link_order
          ,
          comp.i_map_comp ,
          comp.name AS comp_name ,
          CASE
            WHEN comp.i_map_comp = src_cp.i_owner_map_comp
            THEN 0
            ELSE 1
          END AS fetch_predecessor ,
          CASE
            WHEN comp.i_map_comp = tgt_cp.i_owner_map_comp
            THEN 0
            ELSE 1
          END AS fetch_successor ,
          CASE
            WHEN comp.i_map_comp = src_cp.i_owner_map_comp
            THEN tgt_cp.i_owner_map_comp
            ELSE src_cp.i_owner_map_comp
          END AS predecessor_stage ,
          CASE
            WHEN comp.i_map_comp = tgt_cp.i_owner_map_comp
            THEN src_cp.i_owner_map_comp
            ELSE tgt_cp.i_owner_map_comp
          END AS successor_stage ,
          CASE
            WHEN comp.i_map_comp = src_cp.i_owner_map_comp
            THEN tgt_cp.cp_order
            ELSE src_cp.cp_order
          END AS predecessor_link_order ,
          CASE
            WHEN comp.i_map_comp = tgt_cp.i_owner_map_comp
            THEN src_cp.cp_order
            ELSE tgt_cp.cp_order
          END AS successor_link_order
          --, comp.business_name
          --, comp.i_owner_mapping
          --, comp.i_map_comp_type
          ,
          comp.type_name
        FROM prod_odi_repo.snp_map_conn conn
        INNER JOIN prod_odi_repo.snp_map_cp src_cp
        ON src_cp.i_map_cp = conn.i_start_map_cp
        INNER JOIN prod_odi_repo.snp_map_cp tgt_cp
        ON tgt_cp.i_map_cp = conn.i_end_map_cp
        INNER JOIN prod_odi_repo.snp_map_comp comp
        ON (comp.i_map_comp       = tgt_cp.i_owner_map_comp
        OR comp.i_map_comp        = src_cp.i_owner_map_comp )
        WHERE conn.i_owner_mapping=p_mapping_id
        AND comp.i_map_comp       =p_map_comp
        ) conn_relation
    LEFT JOIN
      (SELECT i_map_comp,
        name      AS component_name,
        type_name AS oracle_component_type,
        'Y'       AS FLG
      FROM prod_odi_repo.snp_map_comp
      WHERE i_owner_mapping=p_mapping_id
      ) predecessor_comp
    ON predecessor_comp.i_map_comp=conn_relation.predecessor_stage
    LEFT JOIN
      (SELECT i_map_comp,
        name      AS component_name,
        type_name AS oracle_component_type,
        'Y'       AS FLG
      FROM prod_odi_repo.snp_map_comp
      WHERE i_owner_mapping=p_mapping_id
      ) successor_comp
    ON successor_comp.i_map_comp=conn_relation.successor_stage ;
  BEGIN
    --mapping loop
    FOR c_mapping IN c_snp_mapping
    LOOP
      dbms_output.put_line('{');
      dbms_output.put_line('"MAPPING_NAME":'||'"'||c_mapping.mapping_name||'"');
      --dbms_output.put_line(',');
      --mapping component loop start array
      dbms_output.put_line(',"mapping_components":[');
      FOR c_mapping_comp IN c_snp_map_comp (c_mapping.I_mapping)
      LOOP
        v_iter_map_comp  := v_iter_map_comp + 1;
        IF v_iter_map_comp=1 THEN
          dbms_output.put_line('{');
        ELSE
          dbms_output.put_line(',{');
        END IF;
        -- dbms_output.put_line('======================Start Iteration of Mapping Component: '|| v_iter_map_comp||'======================');
        dbms_output.put_line('"NTH_MAPPING_COMPONENT": '||'"'||v_iter_map_comp||'"');
        dbms_output.put_line(',"I_MAP_COMP": '||'"'|| c_mapping_comp.i_map_comp||'"');
        dbms_output.put_line(',"COMPONENT_NAME":'||'"'|| c_mapping_comp.component_name||'"');
        dbms_output.put_line(',"I_ONWER_MAP_COMP": '||'"'|| c_mapping_comp.i_owner_map_comp||'"');
        dbms_output.put_line(',"TYPE_NAME": '||'"'|| c_mapping_comp.TYPE_NAME||'"');
        dbms_output.put_line(',"I_MAP_REF": '||'"'|| c_mapping_comp.I_MAP_REF||'"');
        DBMS_OUTPUT.PUT_LINE(',"IS_DERIVED_NAME": '||'"'|| c_mapping_comp.IS_DERIVED_NAME||'"');
        --snp_map_cp mapping connection stage category
        --dbms_output.put_line(',');
        --map_connection_point_stage_category start array
        dbms_output.put_line(',"mapping_connpoint_stg_category":[');
        FOR c_stg_category IN c_map_cp_stg_category (c_mapping.i_mapping, c_mapping_comp.i_map_comp)
        LOOP
          v_iter_stg_category  := v_iter_stg_category + 1;
          IF v_iter_stg_category=1 THEN
            dbms_output.put_line('{');
          ELSE
            dbms_output.put_line(',{');
          END IF;
          --dbms_output.put_line('======================Start Iteration of Stage Category within Mapping Component : '|| v_iter_stg_category ||'======================');
          dbms_output.put_line('"NTH_MAP_CP_STG_CATEGORY": '||'"'||v_iter_stg_category||'"');
          dbms_output.put_line(',"I_MAP_CP": '||'"'||c_stg_category.i_map_cp||'"');
          dbms_output.put_line(',"CONNPOINT_NAME": '||'"'||c_stg_category.connpoint_name||'"');
          dbms_output.put_line(',"Business Name": '||'"'||c_stg_category.business_name||'"');
          --dbms_output.put_line(',"CONNPOINT_NAME": '||'"'||c_stg_category.connpoint_name||'"');
          dbms_output.put_line(',"i_owner_map_comp": '||'"'||c_stg_category.i_owner_map_comp||'"');
          dbms_output.put_line(',"direction": '||'"'||c_stg_category.direction||'"');
          ----      case when i_map_cp=p_start_map_cp AND NO_OF_DIRECTIONS=1 then 'SOURCE_ONLY_STAGE'
          --      when i_map_cp=p_end_map_cp and NO_OF_DIRECTIONS=1 then 'TARGET_ONLY_STAGE'
          --      ELSE 'TRANSFORMATION_STAGE' END AS STG_CATEGORY
          dbms_output.put_line(',"NO_OF_DIRECTIONS": '||'"'||c_stg_category.NO_OF_DIRECTIONS||'"');
          --mapping expression start array
          dbms_output.put_line(',"map_expression_per_connpoint":[');
          FOR c_map_expr IN c_snp_map_expr (c_stg_category.i_map_cp)
          LOOP
            v_iter_map_expr  := v_iter_map_expr + 1;
            IF v_iter_map_expr=1 THEN
              dbms_output.put_line('{');
            ELSE
              dbms_output.put_line(',{');
            END IF;
            --dbms_output.put_line('======================Start Iteration of Mapping Expression within Mapping Component : '|| v_iter_map_expr||'======================');
            dbms_output.put_line('"NTH_MAP_EXPRESSION_PER_CP": '||'"'||v_iter_map_expr||'"');
            dbms_output.put_line(',"i_map_expr": '||'"'||c_map_expr.i_map_expr||'"');
            dbms_output.put_line(',"is_parsed": '||'"'||c_map_expr.is_parsed||'"');
            dbms_output.put_line(',"i_map_cp": '||'"'||c_map_expr.i_map_cp||'"');
            dbms_output.put_line(',"I_owner_map_prop": '||'"'||c_map_expr.I_owner_map_prop||'"');
            dbms_output.put_line(',"i_owner_map_attr": '||'"'||c_map_expr.i_owner_map_attr||'"');
            dbms_output.put_line(',"txt": '||'"'||c_map_expr.txt||'"');
            --dbms_output.put_line(dbms_lob.substr(c_map_expr.txt,4000,1));
            dbms_output.put_line(',"txt_clob": '||'"'||c_map_expr.txt_clob||'"');
            dbms_output.put_line(',"parsed_txt": '||'"'||c_map_expr.parsed_txt||'"');
            dbms_output.put_line(',"text_only": '||'"'||c_map_expr.text_only||'"');
            --dbms_output.put_line('======================End Iteration of Mapping Expression within Mapping Component : '|| v_iter_map_expr||'======================');
            dbms_output.put_line('}'); --ending mapping expression per cp object
          END LOOP;                    -- snp_map_expr loop
          dbms_output.put_line(']');   --mapping expression end array
          --mapping attribute start array
          dbms_output.put_line(',"map_attribute_per_connpoint":[');
          FOR c_map_attr IN c_snp_map_attr(c_stg_category.i_map_cp)
          LOOP
            v_iter_map_attr  := v_iter_map_attr + 1;
            IF v_iter_map_attr=1 THEN
              dbms_output.put_line('{');
            ELSE
              dbms_output.put_line(',{');
            END IF;
            --dbms_output.put_line('======================Start Iteration of Mapping Attribute within Mapping Component : '|| v_iter_map_attr ||'======================');
            dbms_output.put_line('"NTH_MAP_ATTRIBUTE_PER_CP": '||'"'||v_iter_map_attr||'"');
            dbms_output.put_line(',"i_map_attr": '||'"'||c_map_attr.i_map_attr||'"');
            dbms_output.put_line(',"attr_name": '||'"'||c_map_attr.attr_name||'"');
            dbms_output.put_line(',"business_name": '||'"'||c_map_attr.business_name||'"');
            dbms_output.put_line(',"i_owner_map_cp": '||'"'||c_map_attr.i_owner_map_cp||'"');
            dbms_output.put_line(',"i_map_ref": '||'"'||c_map_attr.i_map_ref||'"');
            dbms_output.put_line(',"attr_type": '||'"'||c_map_attr.attr_type||'"');
            dbms_output.put_line(',"column_attr_length": '||'"'||c_map_attr.column_attr_length||'"');
            dbms_output.put_line(',"is_required": '||'"'||c_map_attr.is_required||'"');
            dbms_output.put_line(',"sort_pos": '||'"'||c_map_attr.sort_pos||'"');
            dbms_output.put_line(',"is_derived_name": '||'"'||c_map_attr.is_derived_name||'"');
            dbms_output.put_line(',"i_data_map_ref": '||'"'||c_map_attr.i_data_map_ref||'"');
            -- dbms_output.put_line('======================End Iteration of Mapping Attribute within Mapping Component : '|| v_iter_map_attr ||'======================');
            dbms_output.put_line('}'); --ending mapping attribute per cp object
          END LOOP;                    --snp_map_attr mapping attribute loop
          dbms_output.put_line(']');   --mapping attribute end array
          v_iter_map_expr := 0;
          v_iter_map_attr := 0;
          --dbms_output.put_line('======================End Iteration of Stage Category within Mapping Component : '|| v_iter_stg_category ||'======================');
          dbms_output.put_line('}'); --ending mapping connection stage category end category
        END LOOP;                    --snp_map_cp mapping connection stage category loop
        dbms_output.put_line(']');   --mapping_connection_point_stg_category end array
        --mapping reference start array
        dbms_output.put_line(',"map_reference_per_component":[');
        FOR c_map_ref IN c_snp_map_ref ( c_mapping_comp.I_MAP_REF)
        LOOP
          v_iter_map_ref  := v_iter_map_ref + 1;
          IF v_iter_map_ref=1 THEN
            dbms_output.put_line('{');
          ELSE
            dbms_output.put_line(',{');
          END IF;
          --dbms_output.put_line('======================Start Iteration of Mapping Reference within Mapping Component : '|| v_iter_map_ref ||'======================');
          dbms_output.put_line('"NTH_MAP_REFERENCE_PER_COMPONENT": '||'"'||v_iter_map_ref||'"');
          dbms_output.put_line(',"i_map_ref": '||'"'||c_map_ref.i_map_ref||'"');
          dbms_output.put_line(',"i_owner_mapping": '||'"'||c_map_ref.i_owner_mapping||'"');
          dbms_output.put_line(',"qualified_name": '||'"'||c_map_ref.qualified_name||'"');
          dbms_output.put_line(',"i_ref_id": '||'"'||c_map_ref.i_ref_id||'"');
          dbms_output.put_line(',"cod_mod": '||'"'||c_map_ref.cod_mod||'"');
          dbms_output.put_line(',"table_name": '||'"'||c_map_ref.table_name||'"');
          --mapping list of columns per reference start array
          dbms_output.put_line(',"map_list_of_columns_per_ref":[');
          FOR c_col_in_table IN c_snp_col(c_map_ref.table_name)
          LOOP
            v_iter_col  := v_iter_col + 1;
            IF v_iter_col=1 THEN
              dbms_output.put_line('{');
            ELSE
              dbms_output.put_line(',{');
            END IF;
            --dbms_output.put_line('======================Start Iteration of Column details within Mapping Component : '|| v_iter_col ||'======================');
            dbms_output.put_line('"NTH_COLUMN_PER_REF": '||'"'||v_iter_col||'"');
            dbms_output.put_line(',"I_COL": '||'"'||c_col_in_table.I_COL||'"');
            dbms_output.put_line(',"I_table": '||'"'||c_col_in_table.I_table||'"');
            dbms_output.put_line(',"col_name": '||'"'||c_col_in_table.col_name||'"');
            dbms_output.put_line(',"col_heading": '||'"'||c_col_in_table.col_heading||'"');
            dbms_output.put_line(',"col_desc": '||'"'||c_col_in_table.col_desc||'"');
            dbms_output.put_line(',"source_dt": '||'"'||c_col_in_table.source_dt||'"');
            dbms_output.put_line(',"pos": '||'"'||c_col_in_table.pos||'"');
            dbms_output.put_line(',"longc": '||'"'||c_col_in_table.longc||'"');
            dbms_output.put_line(',"scalec": '||'"'||c_col_in_table.scalec||'"');
            dbms_output.put_line(',"file_pos": '||'"'||c_col_in_table.file_pos||'"');
            dbms_output.put_line(',"bytes": '||'"'||c_col_in_table.bytes||'"');
            dbms_output.put_line(',"col_mandatory": '||'"'||c_col_in_table.col_mandatory||'"');
            dbms_output.put_line(',"check_flow": '||'"'||c_col_in_table.check_flow||'"');
            dbms_output.put_line(',"check_stat": '||'"'||c_col_in_table.check_stat||'"');
            --dbms_output.put_line('======================End Iteration of Column details within Mapping Component : '|| v_iter_col ||'======================');
            dbms_output.put_line('}'); --ending list of columns per reference object
          END LOOP;                    -- List of Columns in the table loop
          v_iter_col :=0;
          --dbms_output.put_line('======================End Iteration of Mapping Reference within Mapping Component : '|| v_iter_map_ref||'======================');
          dbms_output.put_line(']'); --ending mapping reference per component array object
          dbms_output.put_line('}'); --mapping reference end object
        END LOOP;                    --mapping reference loop
        dbms_output.put_line(']');   --mapping reference end array
        v_iter_map_ref      := 0;
        v_iter_stg_category := 0;
        dbms_output.put_line(',"mapping_transformations_per_component":[');
        FOR c_snp_prp IN c_snp_map_prop_name (c_mapping_comp.i_map_comp)
        LOOP
          v_iter_map_prop_name  := v_iter_map_prop_name+1;
          IF v_iter_map_prop_name=1 THEN
            dbms_output.put_line('{');
          ELSE
            dbms_output.put_line(',{');
          END IF;
          dbms_output.put_line('"NTH_PROPERTY_NAME_PER_COMPONENT": '||'"'||v_iter_map_prop_name||'"');
          dbms_output.put_line(',"COMPONENT_NAME":'||'"'|| c_mapping_comp.component_name||'"');
          dbms_output.put_line(',"i_map_prop": '||'"'||c_snp_prp.i_map_prop||'"');
          dbms_output.put_line(',"prop_name": '||'"'||c_snp_prp.prop_name||'"');
          dbms_output.put_line(',"business_name": '||'"'||c_snp_prp.business_name||'"');
          dbms_output.put_line(',"i_prop_def": '||'"'||c_snp_prp.i_prop_def||'"');
          dbms_output.put_line(',"i_owner_mapping": '||'"'||c_snp_prp.i_owner_mapping||'"');
          dbms_output.put_line(',"disp_name_key": '||'"'||c_snp_prp.disp_name_key||'"');
          dbms_output.put_line(',"I_map_comp": '||'"'||c_snp_prp.I_map_comp||'"');
          --dbms_output.put_line('}');
          dbms_output.put_line(',"mapping_transformation_expression_per_component":[');
          FOR c_map_transformation_expr IN c_snp_map_transformation_expr(c_snp_prp.i_map_prop)
          LOOP
            v_iter_map_transformation_expr  := v_iter_map_transformation_expr + 1;
            IF v_iter_map_transformation_expr=1 THEN
              dbms_output.put_line('{');
            ELSE
              dbms_output.put_line(',{');
            END IF;
            dbms_output.put_line('"NTH_MAP_TRANFORMATION_EXPRESSION": '||'"'||v_iter_map_transformation_expr||'"');
            dbms_output.put_line(',"COMPONENT_NAME":'||'"'|| c_mapping_comp.component_name||'"');
            dbms_output.put_line(',"i_map_expr": '||'"'||c_map_transformation_expr.i_map_expr||'"');
            dbms_output.put_line(',"is_parsed": '||'"'||c_map_transformation_expr.is_parsed||'"');
            dbms_output.put_line(',"i_map_cp": '||'"'||c_map_transformation_expr.i_map_cp||'"');
            dbms_output.put_line(',"I_owner_map_prop": '||'"'||c_map_transformation_expr.I_owner_map_prop||'"');
            dbms_output.put_line(',"i_owner_map_attr": '||'"'||c_map_transformation_expr.i_owner_map_attr||'"');
            dbms_output.put_line(',"txt": '||'"'||c_map_transformation_expr.txt||'"');
            --dbms_output.put_line(dbms_lob.substr(c_map_expr.txt,4000,1));
            dbms_output.put_line(',"txt_clob": '||'"'||c_map_transformation_expr.txt_clob||'"');
            dbms_output.put_line(',"parsed_txt": '||'"'||c_map_transformation_expr.parsed_txt||'"');
            dbms_output.put_line(',"text_only": '||'"'||c_map_transformation_expr.text_only||'"');
            dbms_output.put_line('}');
          END LOOP;                  --ending mapping transformation expression loop
          dbms_output.put_line(']'); --mapping_transformation expression end array
          dbms_output.put_line('}'); --mapping_transformation name object
          v_iter_map_transformation_expr:=0;
        END LOOP;                  --ending property name per component loop
        dbms_output.put_line(']'); --mapping_transformation_per_component end array
        v_iter_map_prop_name := 0;
        dbms_output.put_line(',"mapping_comp_pre_successor":[');
        FOR c_pre_successor IN c_snp_pre_successor (c_mapping.i_mapping, c_mapping_comp.i_map_comp)
        LOOP
          v_iter_pre_successor  := v_iter_pre_successor+1;
          IF v_iter_pre_successor=1 THEN
            dbms_output.put_line('{');
          ELSE
            dbms_output.put_line(',{');
          END IF;
          dbms_output.put_line('"NTH_MAP_COMP_PRE_SUCCESSOR": '||'"'||v_iter_pre_successor||'"');
          dbms_output.put_line(',"i_map_comp":'||'"'|| c_pre_successor.i_map_comp||'"');
          dbms_output.put_line(',"comp_name":'||'"'|| c_pre_successor.comp_name||'"');
          dbms_output.put_line(',"type_name":'||'"'|| c_pre_successor.type_name||'"');
          dbms_output.put_line(',"predecessor_map_comp":'||'"'|| c_pre_successor.predecessor_map_comp||'"');
          dbms_output.put_line(',"predecessor_map_comp_name":'||'"'|| c_pre_successor.predecessor_map_comp_name||'"');
          dbms_output.put_line(',"predecessor_oracle_comp_type":'||'"'|| c_pre_successor.predecessor_oracle_comp_type||'"');
          dbms_output.put_line(',"predecessor_link_order":'||'"'|| c_pre_successor.predecessor_link_order||'"');
          dbms_output.put_line(',"successor_map_comp":'||'"'|| c_pre_successor.successor_map_comp||'"');
          dbms_output.put_line(',"successor_map_comp_name":'||'"'|| c_pre_successor.successor_map_comp_name||'"');
          dbms_output.put_line(',"successor_oracle_comp_type":'||'"'|| c_pre_successor.successor_oracle_comp_type||'"');
          dbms_output.put_line(',"successor_link_order":'||'"'|| c_pre_successor.successor_link_order||'"');
          dbms_output.put_line('}'); --ending predecessor successor object
        END LOOP;                    --ending predecessor successor component loop
        v_iter_pre_successor :=0;
        dbms_output.put_line(']'); --predecessor successor component end array
        --dbms_output.put_line('======================End Iteration of Mapping Component : '|| v_iter_map_comp||'======================');
        dbms_output.put_line('}'); --ending mapping component object
      END LOOP;                    --mapping component loop
      dbms_output.put_line(']');   --mapping_component end array
      dbms_output.put_line('}');   --mapping end object
    END LOOP;                      --mapping loop
  END;
