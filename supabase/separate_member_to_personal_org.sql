-- ================================================================
-- separate_member_to_personal_org(target_member_id uuid)
--
-- 목적 : 팀장이 팀원을 내보낼 때
--        1. 팀원의 개인 사무소 조회/생성 (중복 생성 금지)
--        2. 팀원 profile 이동 (organization_id + role = owner)
--        3. 팀원이 등록한 매물 organization_id 이동
-- 조건 : 호출자가 owner, 대상이 같은 사무소 member일 것
-- 반환 : (org_id uuid, org_name text)
-- 권한 : SECURITY DEFINER (RLS 우회), authenticated만 허용
-- ================================================================

CREATE OR REPLACE FUNCTION separate_member_to_personal_org(target_member_id uuid)
RETURNS TABLE(org_id uuid, org_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id    uuid := auth.uid();
  v_caller_org   uuid;
  v_caller_role  text;
  v_member_role  text;
  v_new_org_id   uuid;
  v_new_org_name text;
BEGIN
  -- ── 1. 비로그인 거부 ──────────────────────────────────────
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  -- ── 2. 본인 자신 내보내기 거부 ────────────────────────────
  IF target_member_id = v_caller_id THEN
    RAISE EXCEPTION 'cannot kick yourself';
  END IF;

  -- ── 3. 호출자 검증 (owner여야 함) ────────────────────────
  SELECT p.organization_id, p.role
    INTO v_caller_org, v_caller_role
    FROM profiles p
   WHERE p.id = v_caller_id;

  IF v_caller_role != 'owner' THEN
    RAISE EXCEPTION 'only owner can kick a member';
  END IF;

  -- ── 4. 대상 검증 (같은 사무소 member여야 함) ─────────────
  SELECT p.role
    INTO v_member_role
    FROM profiles p
   WHERE p.id = target_member_id
     AND p.organization_id = v_caller_org;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'target member not found in your organization';
  END IF;

  IF v_member_role != 'member' THEN
    RAISE EXCEPTION 'target is not a member role';
  END IF;

  -- ── 5. 개인 사무소 조회 또는 생성 (중복 생성 금지) ───────
  SELECT o.id, o.name
    INTO v_new_org_id, v_new_org_name
    FROM organizations o
   WHERE o.owner_id = target_member_id
  LIMIT 1;

  IF NOT FOUND THEN
    SELECT COALESCE(p.name, '개인') || '의 사무실'
      INTO v_new_org_name
      FROM profiles p
     WHERE p.id = target_member_id;

    v_new_org_id := gen_random_uuid();

    INSERT INTO organizations(id, name, owner_id)
    VALUES (v_new_org_id, v_new_org_name, target_member_id);
  END IF;

  -- ── 6. profile 이동 ───────────────────────────────────────
  UPDATE profiles
     SET organization_id = v_new_org_id,
         role            = 'owner'
   WHERE id = target_member_id;

  -- ── 7. 매물 이전 (팀원이 등록한 매물 → 새 개인 사무소) ───
  UPDATE properties
     SET organization_id = v_new_org_id
   WHERE user_id = target_member_id;

  -- ── 8. 결과 반환 ──────────────────────────────────────────
  RETURN QUERY SELECT v_new_org_id, v_new_org_name;
END;
$$;

-- anon 거부, authenticated만 호출 허용
REVOKE ALL ON FUNCTION separate_member_to_personal_org(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION separate_member_to_personal_org(uuid) TO authenticated;
