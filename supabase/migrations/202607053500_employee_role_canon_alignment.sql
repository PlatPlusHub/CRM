-- SPEC-154 -- the ordinary `employee` role is aligned to canon 28.
--
-- THE DEFECT. Live introspection against `28_permissions_matrix.md`: seventeen permissions that canon
-- marks for the Employee column ("Yes" or "Assigned only") were granted to every role down to
-- `senior_employee` and then stopped. `employee` held 13 permissions and could not create a
-- quotation, create a booking, create a booking item, close a lead, complete a task, resolve a
-- complaint or service request, send a message, or upload a document -- while canon says it should.
--
-- This is an ENGINEERING DEFECT, not a business decision. Canon is explicit and unambiguous:
--
--   CREATE_QUOTATION   | Yes | Yes | Yes | Yes | Yes | Assigned only | No | assigned/department
--   CREATE_BOOKING     | Yes | Yes | Yes | Yes | No  | Yes | Assigned only | No | branch/department
--   CREATE_BOOKING_ITEM| Yes | Yes | Yes | Yes | No  | Yes | Assigned only | No | branch/department
--
-- It is also a KNOWN failure mode in this repository, already corrected once: canon 28's
-- "Amendments ratified with this model" §3 records the identical shape -- *"the seed gave the
-- permission to `owner` and `ceo` only"* -- for `VIEW_BRANCH_DATA`. The seed under-granted; canon did
-- not change.
--
-- WHY THIS MATTERS BEYOND PERMISSIONS. Without it a real employee cannot perform the core of their
-- job on day one: receive a lead, qualify it, quote it, close it, and turn it into a booking. Every
-- other capability this programme has built -- creation events, 360 timelines, the subscription gate,
-- financial privacy -- exists to support a workflow the front-line role could not actually execute.
--
-- SCOPE IS NOT WIDENED. `app.has_permission` answers "does this role hold this capability"; WHERE the
-- role may exercise it is enforced separately by the RLS scope model (SPEC-137): `owner_user_id =
-- app.current_user_id()` for assigned rows, plus the branch/department predicates. Canon's "Assigned
-- only" therefore remains enforced by the policies, not by withholding the permission. Granting the
-- capability without the scope model would have been over-granting; the scope model already exists.
--
-- DELIBERATELY EXCLUDED -- two entries canon does NOT mandate for `employee`:
--
--   * VIEW_FINANCIAL_DOCUMENTS -- canon marks Employee "Assigned related only", but the live
--     permission carries no scope argument: it is used as a BINARY tenant-wide finance gate inside
--     the `payments`, `payment_allocations` and `booking_items` policies. Granting it would hand
--     every employee tenant-wide financial visibility -- far past canon's intent and a direct
--     regression of SPEC-139's employee financial privacy. Canon's scoped intent cannot be expressed
--     by today's binary permission; that contradiction is recorded in SPEC-154, not silently
--     resolved here.
--   * ASSIGN_SUPPLIER -- canon marks Employee "Optional". Optional is not mandated, and granting on
--     an optional marking would be inventing business policy.
--
--   * ENTER_COST and ENTER_SELLING_PRICE -- canon DOES mark these "Assigned only" for Employee, so
--     canon supports the grant. They are withheld anyway, and the reason is the point: the
--     enforcement layer cannot express canon's scope for them. `app.guard_booking_item_financials`
--     calls `app.authorize('ENTER_COST')`, which is role-based ONLY -- it asks whether the ROLE holds
--     the capability and never whether THIS item is the caller's. Granting it would therefore let an
--     employee write cost on a COLLEAGUE's booking item, any item department scope lets them see --
--     which exceeds canon's "assigned" scope rather than implementing it.
--     `29_financial_write_authority_test.sql` assertion 6 proved this within minutes of the grant
--     (it writes to an item the employee "can legitimately see" but does not own).
--     Recorded in SPEC-154 as an engineering gap in the guard, to be closed by making the financial
--     guard scope-aware in its own package. Withholding the permission is the conservative reading;
--     weakening the guard to admit the grant would have been the wrong direction entirely.

-- Note on the two rows this leaves canon-short: after this migration `employee` matches canon 28 on
-- every Employee-column entry EXCEPT ENTER_COST, ENTER_SELLING_PRICE (blocked on the scope gap above)
-- and VIEW_FINANCIAL_DOCUMENTS (blocked on the binary-permission contradiction). All three are
-- tracked; none is silently dropped.

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'employee'
  and p.key in (
      -- Lead lifecycle
      'CLOSE_LEAD',
      -- Task lifecycle
      'COMPLETE_TASK',
      -- Customer service
      'RESOLVE_COMPLAINT', 'RESOLVE_SERVICE_REQUEST',
      -- Quotation lifecycle: the heart of the missing sales workflow
      'CREATE_QUOTATION', 'SEND_QUOTATION', 'ACCEPT_QUOTATION',
      -- Conversations
      'SEND_MESSAGE', 'CLOSE_CONVERSATION',
      -- Booking lifecycle (ENTER_COST / ENTER_SELLING_PRICE deliberately excluded -- see header)
      'CREATE_BOOKING', 'CREATE_BOOKING_ITEM', 'UPDATE_BOOKING_ITEM_STATUS',
      -- Documents
      'UPLOAD_DOCUMENT', 'CREATE_DOCUMENT_VERSION', 'VIEW_TRAVEL_DOCUMENTS'
  )
  and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
  );
