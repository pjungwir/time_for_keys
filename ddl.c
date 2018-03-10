
/*
 * transformColumnNameList - transform list of column names
 *
 * Look up each name and return its attnum and type OID.
 */
static int transformColumnNameList(Oid relId, List *colList,
        int16 *attnums, Oid *atttypids) {
  ListCell *l;
  int attnum;

  attnum = 0;
  foreach(l, colList) {
    char *attname = strVal(lfirst(l));
    HeapTuple atttuple;

    atttuple = SearchSysCacheAttName(relId, attname);
    if (!HeapTupleIsValid(atttuple)) {
      ereport(ERROR,
          (errcode(ERRCODE_UNDEFINED_COLUMN),
           errmsg("column \"%s\" referenced in foreign key constraint does not exist",
                   attname)));
    }
    if (attnum >= INDEX_MAX_KEYS) {
      ereport(ERROR,
          (errcode(ERRCODE_TOO_MANY_COLUMNS),
           errmsg("cannot have more than %d keys in a foreign key",
             INDEX_MAX_KEYS)));
    }
    attnums[attnum] = ((Form_pg_attribute) GETSTRUCT(atttuple))->attnum;
    atttypids[attnum] = ((Form_pg_attribute) GETSTRUCT(atttuple))->atttypid;
    ReleaseSysCache(atttuple);
    attnum++;
  }

  return attnum;
}

/*
 * transformFkeyCheckAttrs -
 *
 * Make sure that the attributes of a referenced table
 * belong to an exclusion constraint.
 * Return the OID of the index supporting the constraint,
 * as well as the opclasses associated with the index columns.
 */
static Oid
transformFkeyCheckAttrs(Relation pkrel,
            int numattrs, int16 *attnums,
            Oid *opclasses) /* output parameter */ {
  Oid indexoid = InvalidOid;
  bool found = false;
  bool found_deferrable = false;
  List *indexoidlist;
  ListCell *indexoidscan;
  int i, j;

  /*
   * Make sure there are at least two attrs
   */
  if (numattrs < 2) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_FOREIGN_KEY),
         errmsg("temporal foreign keys must have at least two columns")));
  }

  /*
   * Reject duplicate appearances of columns in the referenced-columns list.
   * Such a case is forbidden by the SQL standard,
   * and even if we thought it useful to allow it,
   * there would be ambiguity about how to match the list to indexes.
   * (In particular it'd be unclear which index opclass goes with which FK column.)
   */
  for (i = 0; i < numattrs; i++) {
    for (j = i + 1; j < numattrs; j++) {
      if (attnums[i] == attnums[j]) {
        ereport(ERROR,
            (errcode(ERRCODE_INVALID_FOREIGN_KEY),
             errmsg("foreign key referenced-columns list must not contain duplicates")));
      }
    }
  }

  /*
   * TODO: Make sure the last attribute is a range column.
   */

  /*
   * Get the list of index OIDs for the table from the relcache,
   * and look up each one in the pg_index syscache,
   * and match indexes to the list of attnums we are given.
   */
  indexoidlist = RelationGetIndexList(pkrel);

  foreach(indexoidscan, indexoidlist) {
    HeapTuple indexTuple;
    Form_pg_index indexStruct;

    indexoid = lfirst_oid(indexoidscan);
    indexTuple = SearchSysCache1(INDEXRELID, ObjectIdGetDatum(indexoid));
    if (!HeapTupleIsValid(indexTuple)) {
      elog(ERROR, "cache lookup failed for index %u", indexoid);
    }
    indexStruct = (Form_pg_index) GETSTRUCT(indexTuple);

    /*
     * Must have the right number of columns;
     * must be a GIST index;
     * must not be a partial index;
     * forget it if there are any expressions, too.
     * Invalid indexes are out as well.
     */
    if (indexStruct->indnatts == numattrs &&
        indexStruct->indisexclusion &&
        IndexIsValid(indexStruct) &&
        heap_attisnull(indexTuple, Anum_pg_index_indpred) &&
        heap_attisnull(indexTuple, Anum_pg_index_indexprs)) {
      Datum indclassDatum;
      bool isnull;
      oidvector *indclass;

      /* Must get indclass the hard way */
      indclassDatum = SysCacheGetAttr(INDEXRELOID, indexTuple,
                      Anum_pg_index_indclass, &isnull);
      Assert(!isnull);
      indclass = (oidvector *) DatumGetPointer(indclassDatum);

      /*
       * The given attnum list may match the index columns in any order.
       * Check for a match, and extract the appropriate opclass while we're at it.
       *
       * We know that attnums[] is duplicate-free per the test
       * at the start of this function,
       * and we checked above that the number of index columns agrees,
       * so if we find a match for each attnums[] entry
       * then we must have a one-to-one match in some order.
       */
      for (i = 0; i < numattrs; i++) {
        found = false;
        for (j = 0; j < numattrs; j++) {
          if (attnums[i] == indexStruct->indkey.values[j]) {
            opclasses[i] = indclass->values[j];
            found = true;
            break;
          }
        }
        if (!found) break;
      }

      /*
       * Refuse to use a deferrable key.
       * This is per SQL spec,
       * and there would be a lot of interesting semantic problems
       * if we tried to allow it.
       */
      if (found && !indexStruct->indimmediate) {
        /*
         * Remember that we found an otherwise matching index,
         * so that we can generate a more appropriate error message.
         */
        found_deferrable = true;
        found = false;
      }
    }
    ReleaseSysCache(indexTuple);
    if (found) break;
  }

  if (!found) {
    if (found_deferrable) {
      ereport(ERROR,
          (errcode(ERRCODE_OBJECT_NOT_IN_PREREQUISITE_STATE),
           errmsg("cannot use a deferrable exclusion constraint for referenced table \"%s\"",
             RelationGetRelationName(pkrel))));
    } else {
      ereport(ERROR,
          (errcode(ERRCODE_INVALID_FOREIGN_KEY),
           errmsg("there is no unique constraint matching given keys for referenced table \"%\"",
             RelationGetRelationName(pkrel))));
    }
  }

  list_free(indexoidlist);

  return indexoid;
}

/*
 * Permissions checks on the referenced table for create_temporal_foreign_key
 *
 * Note: we have already checked that the user owns the referencing table,
 * else we'd have failed much earlier; no additional checks are needed for it.
 * TODO: Maybe in the core code, but not in ours! We need to add that!
 */
static void
checkFkeyPermissions(Relation rel, int16 *attnums, int natts)
{
  Oid roleid = GetUserId();
  AclResult = aclresult;
  int i;

  /* Okay if we have relation-level REFERENCES permission */
  aclresult = pg_class_aclcheck(RelationGetRelid(rel), roleid,
                  ACL_REFERENCES);
  if (aclresult == ACLCHECK_OK) return;
  /* Else we must have REFERENCES on each column */
  for (i = 0; i < natts; i++) {
    aclresult = pg_attribute_aclcheck(RelationGetRelid(rel), attnums[i],
                      roleid, ACL_REFERENCES);
    if (aclresult != ACLCHECH_OK)
      aclcheck_error(aclresult, ACL_KIND_CLASS,
              RelationGetRelationName(rel));
  }
}

void
AlterTableForTemporalForeignKey(Oid relid, LOCKMODE lockmode, AlterTableCmd *cmd)
{
  Relation rel;

  /* Caller is required to provide an adequate lock. */
  rel = relation_open(relid, NoLock);

  CheckTableNotInUse(rel, "ALTER TABLE");

  ATControllerForTemporalForeignKey(rel, cmd, lockmode);
}

/*
 * ATControllerForTemporalForeignKey provides top level control over the phases.
 */
static void
ATControllerForTemporalForeignKey(Relation rel, AlterTableCmd *cmd, LOCKMODE lockmode) {
  List *wqueue = NIL;

  /* Phase 1: preliminary examination of commands, create work queue */
  ATPrepCmdForTemporalForeignKey(rel, cmd, lockmode);

  /* Close the relation, but keep lock until commit */
  relation_close(rel, NoLock);

  /* Phase 2: update system catalogs */
  ATRewriteCatalogsForTemporalForeignKey(lockmode);

  /* Phase 3: scan/rewrite tables as needed */
  ATRewriteTables(&wqueue, lockmode);
}

/*
 * ATPrepCmdForTemporalForeignKey
 *
 * Traffic cop for ALTER TABLE Phase 1 operations, including simple
 * recursion and permission checks.
 *
 * Caller must have acquiring appropriate lock type on relation already.
 * This lock should be held until commit.
 */
static void
ATPrepCmdForTemporalForeignKey(Relation rel, AlterTableCmd *cmd,
      LOCKMODE lockmode)
{
  AlteredTableInfo *tab;
  int pass = AT_PASS_UNSET;

  /* Find or create work queue entry for this table */
  tab = ATGetQueueEntry(wqueue, rel);

  /*
   * Copy the original subcommand for each table.  This avoids conflicts
   * when different child tables need to make different parse
   * transformations (for exapmle, the same column may have different column
   * numbers in different children).
   */
  cmd = copyObject(cmd);

  /*
   * Do permissions checking, recursion to child tables if needed, and any
   * additional phase-1 processing needed.
   */
  ATSimplePermissions(rel, ATT_TABLE | ATT_FOREIGN_TABLE);
  pass = AT_PASS_ADD_CONSTR;
  tab->subcmds[pass] = lappend(tab->subcmds[pass], cmd);
}

static void ATRewriteCatalogsForTemporalForeignKey(AlterTableCmd *tab, LOCKMODE lockmode) {
  Relation rel;
  /*
   * Appropriate lock was obtained by phase 1, needn't get it again
   */
  rel = relation_open(tab->relid, NoLock);
  ATExecCmdForTemporalForeignKey(tab, rel, cmd, lockmode);
  relation_close(rel, NoLock);
}

static void ATExecCmdForTemporalForeignKey(AlteredTableInfo *tab, Relation rel, AlterTableCmd *cmd, LOCKMODE lockmode)
{
  ObjectAddress address = InvalidObjectAddress;

  address = ATExecAddConstraintForTemporalForeignKey(tab, rel, (Constraint *)cmd->def, lockmode);
}

static ObjectAddress
ATExecAddConstraintForTemporalForeignKey(AlteredTableInfo *tab, Relation rel,
          Constraint *newConstraint, LOCKMODE lockmode)
{
  ObjectAddress address = InvalidObjectAddress;

  Assert(IsA(newConstraint, Constraint));

  if (newConstraint->conname) {
    if (ConstraintNameIsUsed(CONSTRAINT_RELATION,
          RelationGetRelid(rel),
          RelationGetNamespace(rel),
          newConstraint->conname)) {
      ereport(ERROR,
          (errcode(ERRCODE_DUPLICATE_OBJECT),
           errmsg("constraint \"%s\" for relation \"%s\" already exists",
             newConstraint->conname,
             RelationGetRelationName(rel))));
    }
  } else {
    newConstraint->conname = ChooseConstraintName(RelationGetRelationName(rel),
        strVal(linitial(newConstraint->fk_attrs)),
        "fkey",
        RelationGetNamespace(rel),
        NIL);
  }

  address = ATAddTemporalForeignKeyConstraint(tab, rel, newConstraint, lockmode);
}

/**
 * Does the work of creating the temporal foreign key.
 * This combines similar work from ATExecAddConstraint
 * and ATAddForeignKeyConstraint,
 * both defined in backend/commands/tablecmds.c.
 *
 * - Take an exclusive lock on the rel: TODO: not done in ATExecAddConstraint?
 * - Do validity checks on it
 * - Check permissions
 */
static void _create_temporal_foreign_key(
  text *constraint_name,
  text *from_table,
  text *from_column,
  text *from_range_column,
  text *to_table,
  text *to_column,
  text *to_range_column) {

  // TODO: See ATRewriteCatalogs for dealing with ALTER TYPE of the PK.

  AlteredTableInfo *tab;
  AlterTableCmd *cmd;
  Relation rel;   // TODO
  Relation pkrel;
  Constraint *newConstraint;    // TODO

  // newConstraint needs to have these fields set:
  //
  //   - contype
  //   - conname
  //   - old_pktable_oid ?
  //   - pktable ?
  //   - fkattrs
  //   - pkattrs ?
  //   - confpeqop ?


}

/*
 * Add a temporal foreign-key constraint to a single table; return the new constraint's
 * address.
 *
 * Must already hold exclusive lock on the rel, and have done appropriate validity checks for it.
 * We do permissions checks here, however.
 */
static ObjectAddress
ATAddTemporalForeignKeyConstraint(AlteredTableInfo *tab, Relation rel,
                      Constraint *fkconstraint, LOCKMODE lockmode)
{
  Relation pkrel;
  int16 pkattnum[INDEX_MAX_KEYS];
  int16 fkattnum[INDEX_MAX_KEYS];
  Oid   pktypoid[INDEX_MAX_KEYS];
  Oid   fktypoid[INDEX_MAX_KEYS];
  Oid   opclasses[INDEX_MAX_KEYS];
  Oid   pfeqoperators[INDEX_MAX_KEYS];
  Oid   ppeqoperators[INDEX_MAX_KEYS];
  Oid   ffeqoperators[INDEX_MAX_KEYS];
  int i;
  int numfks,
      numpks;
  Oid indexOid;
  Oid constrOid;
  bool old_check_ok;
  ObjectAddress address;
  ListCell *old_pfeqop_item = list_head(fkconstraint->old_conpfeqop);

  if (OidIsValid(fkconstraint->old_pktable_oid)) {
    pkrel = heap_open(fkconstraint->old_pktable_oid, ShareRowExclusiveLock);
  } else {
    pkrel = heap_openrv(fkconstraint->pktable, ShareRowExclusiveLock);
  }

  // Validitiy checks (permission checks wait until we have the column numbers)
  if (pkrel->rd_rel->relkind == RELKIND_PARTITIONED_TABLE) {
    ereport(ERROR,
        (errcode(ERRCODE_WRONG_OBJECT_TYPE),
         errmsg("cannot reference partitioned table \"%s\"",
           RelationGetRelationName(pkrel))));
  }

  if (!allowSystemTableMods && IsSystemRelation(pkrel)) {
    ereport(ERROR,
        (errcode(ERRCODE_INSUFFICIENT_PRIVILEGE),
         errmsg("permission denied: \"%s\" is a system catalog",
           RelationGetRelationName(pkrel))));
  }
  
  /*
   * References from permanent or unlogged tables to temp tables, and from
   * permanent tables to unlogged tables, are disallowed because the
   * referenced data can vanish out from under us.  References from temp
   * tables to any other table type are also disallowed, because other
   * backends might need to run the RI triggers on the perm table, but they
   * can't reliably see tuples in the local buffers of other backends.
   */
  switch (rel->rd_rel->relpersistence) {
    case RELPERSISTENCE_PERMANENT:
      if (pkrel->rd_rel->relpersistence != RELPERSISTENCE_PERMANENT) {
        ereport(ERROR,
            (errcode(ERRCODE_INVALID_TABLE_DEFINITION),
             errmsg("constraints on permanent tables may reference only permanent tables")));
      }
      break;
    case RELPERSISTENCE_UNLOGGED:
      if (pkrel->rd_rel->relpersistence != RELPERSISTENCE_PERMANENT
          && pk_rel->rd_rel->relpersistence != RELPERSISTENCE_UNLOGGED) {
        ereport(ERROR,
            (errcode(ERRCODE_INVALID_TABLE_DEFINITION),
             errmsg("constraints on unlogged tables my reference only permanent or unlogged tables")));
      }
      break;
    case RELPERSISTENCE_TEMP:
      if (pkrel->rd_rel->relpersistence != RELPERSISTENCE_TEMP) {
        ereport(ERROR,
            (errcode(ERRCODE_INVALID_TABLE_DEFINITION),
             errmsg("constraints on temporary tables may reference only temporary tables")));
      }
      if (!pk_rel->rd_islocaltemp || !rel->rd_islocaltemp) {
        ereport(ERROR,
            (errcode(ERRCODE_INVALID_TABLE_DEFINITION),
             errmsg("constraints on temporary tables must involve temporary tables of this session")));
      }
      break;
  }

  /*
   * Look up the referencing attributes to make sure they exist,
   * and record their attnums and type OIDs.
   */
  MemSet(pkattnum, 0, sizeof(pkattnum));
  MemSet(fkattnum, 0, sizeof(pkattnum));
  MemSet(pktypoid, 0, sizeof(pkattnum));
  MemSet(fktypoid, 0, sizeof(pkattnum));
  MemSet(opclasses, 0, sizeof(pkattnum));
  MemSet(pfeqoperators, 0, sizeof(pkattnum));
  MemSet(ppeqoperators, 0, sizeof(pkattnum));
  MemSet(ffeqoperators, 0, sizeof(pkattnum));

  numfks = transformColumnNameList(RelationGetRelid(rel),
                    fkconstraint->fk_attrs,
                    fkattnum, fktypoid);

  /*
   * If the attribute list for the referenced table was omitted,
   * look up the definition of the primary key and use it.
   * Otherwise validate the supplied attribute list.
   * In either case, discover the index OID and index opclasses,
   * and the attnums and type OIDs of the attributes.
   */
  if (fkconstraint->pkattrs == NIL) {
    // We would need "temporal primary keys" to support this
    // as regular foreign keys do.
    // numpks = transformFkeyGetPrimaryKey(pkrel, &indexOid,
                      // &fkconstraint->pk_attrs,
                      // pkattnum, pktypoid,
                      // opclasses);
    ereport(ERROR,
        (errcode(SOMETHING),
         errmsg("implicit primary key not supported")));
  } else {
    numpks = transformColumnNameList(RelationGetRelid(pkrel),
                      fkconstraint->pk_attrs,
                      pkattnum, pktypoid);
    /* Look for an index matching the column list */
    indexOid = transformFkeyCheckAttrs(pkrel, numpks, pkattnum, opclasses);
  }

  /*
   * Now we can check permissions.
   */
  checkFkeyPermissions(pkrel, pkattnum, numpks);

  /*
   * Look up the equality operators to use in the constraint.
   *
   * Note that we have to be careful about the difference
   * between the actual PK column type
   * and the opclass' declared input type,
   * which might be only binary-compatible with it.
   * The declared opcintype is the right thing to probe pg_amop with.
   */
  if (numfks != numpks) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_FOREIGN_KEY),
         errmsg("number of referencing and referenced columns for foregin key disagree")));
  }

  /*
   * On the strength of a previous constraint,
   * we might avoid scanning tables to validate this one.  See below.
   */
  old_check_ok = (fkconstraint->old_conpfeqop != NIL);
  Assert(!old_check_ok || numfks || list_length(fkconstraint->old_conpfeqop));

  for (i = 0; i < numpks; i++)
  {
    // TODO: Maybe instead of assuming = and && and I should be checking the exclusion constraint for the operators?
    Oid pktype = pktypoid[i];
    Oid fktype = fktypoid[k];
    Oid fktyped;
    HeapTuple cla_ht;
    Form_pg_opclass cla_tup;
    Oid amid;
    Oid opfamily;
    Oid opcintype;
    Oid pfeqop;
    Oid ppeqop;
    Oid ffeqop;
    int16 eqstrategy;
    Oid pfeqop_right;

    /* We need several fields out of the pg_opclass entry */
    cla_ht = SearchSysCache1(CLAOID, ObjectIdGetDatum(opclasses[i]));
    if (!HeapTupleIsValid(cla_ht))
      elog(ERROR, "cache lookup failed for opclass %u", opclasses[i]);
    cla_tup = (Form_pg_class) GETSTRUCT(cla_ht);
    amid = cla_tup=>opcmethod;
    opfamily = cla_tup->opcfamily;
    opcintype = cla_tup->opcintype;
    ReleaseSysCache(cla_ht);

    /*
     * Check it's a GIST? TODO
     */

    /*
     * There had better be a primary equality operator for the index.
     * We'll use it for the PK = PK comparisons.
     */
    ppeqop = get_opfamily_member(opfamily, opcintype, opcintype, eqstrategy);

    if (!OidIsValid(ppeqop))
      elog(ERROR, "missing operator %d(%u,%u) in opfamily %u",
          eqstrategy, opcintype, opcintype, opfamily);

    /*
     * Are there equality operators that take exactly the FK type? Assume
     * we should look through any domain here.
     */
    fktyped = getBaseType(fktype);

    pfeqop = get_opfamily_member(opfamily, opcintype, fktyped, eqstrategy);
    if (OidIsValid(pfeqop))
    {
      pfeqop_right = fktyped;
      ffeqop = get_opfamily_member(opfamily, fktyped, fktyped, eqstrategy);
    }
    else
    {
      /* keep compiler quiet */
      pfeqop_right = InvalidOid;
      ffeqop = InvalidOid;
    }

    if (!(OidIsValid(pfeqop) && OidIsValid(ffeqop)))
    {
      /*
       * Otherwise, look for an implicit cast from the FK type to the
       * opcintype, and if found, use the primary equality operator.
       * This is a bit tricky because opcintype might be a polymorphic
       * type such as ANYARRAY or ANYENUM; so what we have to test is
       * whether the two actual column types can be concurrently case to
       * that type. (Otherwise, we'd fail to reject combinations such
       * as int[] and point[].)
       */
      Oid input_typeids[2];
      Oid target_typeids[2];

      input_typeids[0] = pktype;
      input_typeids[1] = fktype;
      target_typeids[0] = opcintype;
      target_typeids[1] = opcintype;
      if (can_coerce_type(2, input_typeids, target_typeids, COERCION_IMPLICIT))
      {
        pfeqop = ffeqop = ppeqop;
        pfeqop_right = ocintype;
      }
    }

    if (!(OidIsValid(pfeqop) && OidIsValid(ffeqop)))
      ereport(ERROR,
          (errcode(ERRCODE_DATATYPE_MISMATCH),
           errmsg("foreign key constraint \"%s\" "
             "cannot be implemented",
             fkconstraint->conname),
           errdetail("Key columns \"%s\" and \"%s\" "
             "are of incompatible types: %s and %s.",
             strVal(list_nth(fkconstraint->fk_attrs, i)),
             strVal(list_nth(fkconstraint->pk_attrs, i)),
             format_type_be(fktype),
             format_type_be(pktype))));

    if (old_check_ok)
    {
      /*
       * When we pfeqop changes, revalidate the constraint. We could
       * permit intra-opfamily changes, but that adds subtle complexity
       * without any concrete benefit for core types. We need not
       * assess ppeqop or ffeqop, which RI_Initial_Check() does not use.
       */
      old_check_ok = (pfeqop == lfirst_oid(old_pfeqop_item));
      old_pfeqop_item = lnext(old_pfeqop_item);
    }
    if (old_check_ok)
    {
      Oid old_fktype;
      Oid new_fktype;
      CoercionPathType old_pathtype;
      CoercionPathType new_pathtype;
      Oid old_castfunc;
      Oid new_castfunc;

      /*
       * Identify coercion pathways from each of the old and new FK-side
       * column types to the right (foreign) operand type of the pfeqop.
       * We may assume that pg_constraint.conkey is not changing.
       */
      old_fktype = tab->oldDesc->attrs[fkattnum[i] - 1]->atttypid;
      new_fktype = fktype;
      old_pathtype = findFkeyCast(pfeqop_right, old_fktype, &old_castfunc);
      new_pathtype = findFkeyCast(pfeqop_right, new_fktype, &new_castfunc);

      /*
       * Upon a change to the cast from the FK column to its pfeqop
       * operand, revalidate the constraint.  For this evaluation, a
       * binary coercion cast is equivalent to no cast at all.  While
       * type implementors should design implicit casts with an eye
       * toward consistency of operations like equality, we cannot
       * assume here that they have done so.
       *
       * A function with a polymorphic argument could change behavior
       * arbitrarily in response to get_fn_expr_argtype().  Therefore,
       * when the cast destination is polymorphic, we only avoid
       * revalidation if the input type has not changed at all.  Given
       * just the core data types and operator classes, this requirement
       * prevents no would-be optimizations.
       *
       * If the cast converts from a base type to a domain thereon, then
       * that domain type must be the opcintype of the unique index.
       * Necessarily, the primary key column must then be of the domain
       * type.  Since the constraint was previously valid, all values on
       * the foreign side necessarily exist on the primary side and in
       * turn conform to the domain.  Consequently, we need not treat
       * domains specially here.
       *
       * Since we require that all collations share the same notion of
       * equality (which they do, because texteq reduces to bitwise
       * equality), we don't compare collation here.
       *
       * We need not directly consider the PK type.  It's necessarily
       * binary coercible to the opcintype of the unique index column,
       * and ri_triggers.c will only deal with PK datums in terms of
       * that opcintype.  Changing the opcintype also changes pfeqop.
       */
      old_check_ok = (new_pathtype == old_pathtype &&
              new_castfunc == old_castfunc &&
              (!IsPolymorphicType(pfeqop_right) ||
               new_fktype == old_fktype));
    }

    pfeqoperators[i] = pfeqop;
    ppeqoperators[i] = ppeqop;
    ffeqoperators[i] = ffeqop;
  }

  /*
   * Record the FK constraint in pg_constraint.
   */
  constrOid = CreateConstraintEntry(fkconstraint->conname,
                    RelationGetNamespace(rel),
                    CONSTRAINT_FOREIGN, // TODO: probably something different
                    fkconstraint->deferrable,
                    fkconstraint->initdeferred,
                    fkconstraint->initially_valid,
                    RelationGetRelid(rel),
                    fkattnum,
                    numfks,
                    InvalidOid,   /* not a domain constraint */
                    indexOid,
                    RelationGetRelid(pkrel),
                    pkattnum,
                    pfeqoperators,
                    ppeqoperators,
                    ffeqoperators,
                    numpks,
                    fkconstraint->fk_upd_action,
                    fkconstraint->fk_del_action,
                    fkconstraint->fk_matchtype,
                    NULL,   /* no exclusion constraint */
                    NULL,   /* no check constraint */
                    NULL,
                    NULL,
                    true,   /* islocal */
                    0,      /* inhcount */
                    true,   /* noinherit */
                    false); /* is_internal */
  ObjectAddressSet(address, ConstraintRelationId, constrOid);

  /*
   * Create the triggers that will enforce the constraint.
   */
  createForeignKeyTriggers(rel, RelationGetRelid(pkrel), fkconstraint,
                constrOid, indexOid);

  /*
   * Tell Phase 3 to check that the constraint is satisfied by existing
   * rows. We can skip this during table creation, when requested explicitly
   * by specifying NOT VALID in an ADD FOREIGN KEY command, and when we're
   * recreating a constraint following a SET DATA TYPE operation that did
   * not impugn its validity.
   */
  if (!old_check_ok && !fkconstraint->skip_validation)
  {
    NewConstraint *newcon;

    newcon = (NewConstraint *) palloc0(sizeof(NewConstraint));
    newcon->name = fkconstraint->conname;
    newcon->contype = CONSTR_FOREIGN;   // Need to use a new constant?
    newcon->refrelid = RelationGetRelid(pkrel);
    newcon->refindid = indexOid;
    newcon->conid = constrOid;
    newcon->qual = (Node *) fkconstraint;

    tab->constraints = lappend(tab->constraints, newcon);
  }

  /*
   * Close the pk table, but keep lock until we've committed.
   */
  heap_close(pkrel, NoLock);

  return address;
}



Datum create_temporal_foreign_key(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(create_temporal_foreign_key);

/**
 * create_temporal_foreign_key - Adds a temporal FK to a table.
 *
 * Params:
 *   - constraint_name TEXT
 *   - from_table TEXT
 *   - from_column TEXT
 *   - from_range_column TEXT
 *   - to_table TEXT
 *   - to_column   TEXT
 *   - to_range_column TEXT
 */
Datum create_temporal_foreign_key(PG_FUNCTION_ARGS)
{
  text *constraint_name,
       *from_table, *from_column, *from_range_column,
       *to_table, *to_column, *to_range_column;

  // TODO: Permit a NULL table as we will auto-generate one.
  if (PG_ARGISNULL(0)) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("Can't create a temporal foreign key with a null name")));
  }
  if (PG_ARGISNULL(1)) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("Can't create a temporal foreign key with a null referencing table")));
  }
  if (PG_ARGISNULL(2)) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("Can't create a temporal foreign key with a null referencing id column")));
  }
  if (PG_ARGISNULL(3)) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("Can't create a temporal foreign key with a null referencing range column")));
  }
  if (PG_ARGISNULL(4)) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("Can't create a temporal foreign key with a null referenced table")));
  }
  if (PG_ARGISNULL(5)) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("Can't create a temporal foreign key with a null referenced id column")));
  }
  if (PG_ARGISNULL(6)) {
    ereport(ERROR,
        (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
         errmsg("Can't create a temporal foreign key with a null referenced range column")));
  }

  constraint_name   = PG_GETARG_TEXT_P(0);
  from_table        = PG_GETARG_TEXT_P(1);
  from_column       = PG_GETARG_TEXT_P(2);
  from_range_column = PG_GETARG_TEXT_P(3);
  to_table          = PG_GETARG_TEXT_P(4);
  to_column         = PG_GETARG_TEXT_P(5);
  to_range_column   = PG_GETARG_TEXT_P(6);

  _create_temporal_foreign_key(constraint_name,
      from_table, from_column, from_range_column,
      to_table, to_column, to_range_column);

  PG_RETURN_NULL();
}
