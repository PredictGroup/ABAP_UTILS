FUNCTION ZFM_PLANT_HIER_TRANSFER
  IMPORTING
    I_S_HIEBAS TYPE RSAP_S_HIEBAS
    I_S_HIEFLAG TYPE RSAP_S_HIEFLAG
    I_S_HIERSEL TYPE RSAP_S_HIER_LIST
  TABLES
    I_T_LANGU TYPE SBIWM_T_LANGU
    E_T_HIETEXT TYPE RSAP_T_HIETEXT
    E_T_HIENODE TYPE RSAP_T_HIENODE
    E_T_FOLDERT TYPE RSAP_T_FOLDERT OPTIONAL
    E_T_HIEINTV TYPE RSAP_T_HIEINTV OPTIONAL
  EXCEPTIONS
    INVALID_HIERARCHY_FLAG
    APPLICATION_ERROR.



* - bw extraction plant hierarchy.

  TYPE-POOLS: rsap.

  DATA: lt_hiers LIKE rshiertrsf OCCURS 0 WITH HEADER LINE,
        lt_nodetab LIKE snodetext OCCURS 0 WITH HEADER LINE,
        lv_linked_node LIKE roshienode-link.

*---- define application data
  DATA: lt_hierarchies TYPE hierarchies,
        ls_hierarchy   LIKE LINE OF lt_hierarchies.


  gv_datefrom     = i_s_hiersel-datefrom.
  gv_dateto       = i_s_hiersel-dateto.

*---- get text of hierarchie
  IF i_s_hieflag-hietabfl IS INITIAL.
    RAISE invalid_hierarchy_flag.
  ENDIF.
  gv_this_info_object = '0PLANT'.

  CLEAR: e_t_hietext, e_t_hietext[].
  CLEAR: e_t_foldert, e_t_foldert[].
  CLEAR: e_t_hienode, e_t_hienode[].

  e_t_hienode-iobjnm = '0HIER_NODE'.
  e_t_hienode-nodename = 'ALL'.
  e_t_hienode-tlevel = 1.
  e_t_hienode-datefrom = '10000101'.
  e_t_hienode-datefrom = '99991231'.

  APPEND e_t_hienode.
* // Get texts of root
  LOOP AT i_t_langu WHERE langu = 'R'.
    CLEAR e_t_foldert.
    MOVE i_t_langu-langu TO e_t_foldert-langu.
    MOVE i_t_langu-langu TO e_t_hietext-langu.
    MOVE '0HIER_NODE' TO e_t_foldert-iobjnm.
*    MOVE '~ROOT' TO e_t_foldert-nodename.
    MOVE 'ALL' TO e_t_foldert-nodename.

    e_t_hietext-txtsh = 'Plant Hier Name'.
    e_t_hietext-txtmd = 'Plant Hier Name'.
    e_t_hietext-txtlg = 'Plant Hier Name'.

    MOVE e_t_hietext-txtsh TO e_t_foldert-txtsh.
    MOVE e_t_hietext-txtmd TO e_t_foldert-txtmd.
    MOVE e_t_hietext-txtlg TO e_t_foldert-txtlg.

    APPEND e_t_foldert.
    APPEND e_t_hietext.

  ENDLOOP.

*---- if datasource time-independent -> Take current date
  IF i_s_hieflag-hiendtfl IS INITIAL.
    gv_datefrom = sy-datum.
    gv_dateto = '99991231'.
  ENDIF.

*---- get plant hierarchy
  SELECT * FROM wrf1 INTO TABLE lt_hierarchies
    WHERE locnr >= '0000002001'
          AND locnr <= '0000002999'.

  LOOP AT lt_hierarchies INTO ls_hierarchy.

    PERFORM setbwnode TABLES e_t_hienode
        USING ls_hierarchy '2'
        CHANGING lv_linked_node.

* node texts
    LOOP AT i_t_langu WHERE langu = 'R'.

      CLEAR e_t_foldert.
      MOVE i_t_langu-langu TO e_t_foldert-langu.
      MOVE '0PLANT' TO e_t_foldert-iobjnm.
      MOVE ls_hierarchy-locnr+6(4) TO e_t_foldert-nodename.

      MOVE ls_hierarchy-locnr+6(4) TO e_t_foldert-txtsh.
      MOVE ls_hierarchy-locnr+6(4) TO e_t_foldert-txtmd.
      MOVE ls_hierarchy-locnr+6(4) TO e_t_foldert-txtlg.

      APPEND e_t_foldert.

    ENDLOOP.

  ENDLOOP.

*---- set tlevel of hierarchy table for next call
  LOOP AT e_t_hienode.

    MOVE e_t_hienode-nodename TO lt_nodetab-name.
    MOVE e_t_hienode-tlevel TO lt_nodetab-tlevel.
    MOVE e_t_hienode-link TO lt_nodetab-link.
    e_t_hienode-nodeid = sy-tabix.
    MODIFY e_t_hienode.
    APPEND lt_nodetab.

  ENDLOOP.

*---- get index data for parent child next depending on tlevel
  CALL FUNCTION 'RS_TREE_CONSTRUCT'
    TABLES
      nodetab            = lt_nodetab
    EXCEPTIONS
      tree_failure       = 1
      id_not_found       = 2
      wrong_relationship = 3
      OTHERS             = 4.
  IF sy-subrc NE 0.
    RAISE application_error.
  ENDIF.

*---- pass data to original table
  DATA: l_hlp_sy_tabix LIKE sy-tabix.
  LOOP AT lt_nodetab.

    l_hlp_sy_tabix = sy-tabix.
    READ TABLE e_t_hienode INDEX l_hlp_sy_tabix.

    CHECK sy-subrc = 0.

    e_t_hienode-link = lt_nodetab-link.
    e_t_hienode-parentid = lt_nodetab-parent.
    e_t_hienode-childid = lt_nodetab-child.
    e_t_hienode-nextid = lt_nodetab-next.
    e_t_hienode-datefrom = '10000101'.
    e_t_hienode-dateto = '99991231'.
    MODIFY e_t_hienode INDEX l_hlp_sy_tabix.

  ENDLOOP.


ENDFUNCTION.