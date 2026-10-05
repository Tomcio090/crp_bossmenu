local data = {}
local bossmenuData = {}

lib.callback.register('crp_jobcore:bossmenu:server:getBossmenuData', function(source, job)
    if not source then return {} end
    return data.getBossmenuData(job)
end)

function data.getEmployeeData(job)
    local employess = {}
    if not job then return employess end
    local rows = MySQL.query.await(([[
        SELECT u.%s AS identifier, u.%s AS firstname, u.%s AS lastname, u.job_grade AS grade, u.%s AS ssn, u.%s AS phone,
               m.identifier AS m_id, m.badge, m.seconds, DATE_FORMAT(m.hired_at, '%s') AS hired_at,
               TIMESTAMPDIFF(MINUTE, COALESCE(m.last_duty, m.hired_at), NOW()) AS last_seen,
               m.note, m.note_by, DATE_FORMAT(m.note_at, '%s') AS note_at
        FROM %s u LEFT JOIN bossmenu_members m ON m.identifier = u.%s AND m.job = ?
        WHERE u.job = ?]]):format(q(COL.identifier), q(COL.firstname), q(COL.lastname), q(COL.ssn), q(COL.phone),
        FMT_D, FMT_DT, q(COL.users), q(COL.identifier)), { job, job })

    local lic = group(MySQL.query.await(([[SELECT identifier, license, DATE_FORMAT(granted_at, '%s') AS at FROM bossmenu_licenses WHERE job = ?]]):format(FMT_D), { job }), 'identifier')
    local rec = group(MySQL.query.await(([[SELECT id, identifier, kind, reason, by_name, DATE_FORMAT(created_at, '%s') AS at,
        void_by, DATE_FORMAT(void_at, '%s') AS void_at, void_reason FROM bossmenu_records WHERE job = ? ORDER BY id DESC LIMIT 3000]]):format(FMT_DT, FMT_DT), { job }), 'identifier')
    local pro = group(MySQL.query.await(([[SELECT identifier, from_grade, to_grade, by_name, reason, DATE_FORMAT(created_at, '%s') AS at
        FROM bossmenu_promotions WHERE job = ? ORDER BY id DESC LIMIT 3000]]):format(FMT_DT), { job }), 'identifier')

    local missing = {}
    for _, r in ipairs(rows) do
        local grade, status = r.grade, 'off'
        local x = Bridge.GetPlayerByIdentifier(r.identifier)
        local skip = false
        if x then
            if x.job.name ~= job then skip = true
            else grade = x.job.grade; status = statusFn(x.source, x) end
        end
        if not skip then
            if not r.m_id then missing[#missing + 1] = r.identifier end
            local e = {
                ssn = r.ssn or r.identifier, firstname = r.firstname, lastname = r.lastname, phonenumber = r.phone or '',
                grade = grade, status = status, lastSeen = status == 'off' and (r.last_seen or 0) or 0,
                badge = r.badge, hiredAt = r.hired_at or os.date('%d.%m.%Y'),
                hoursWeek = math.floor(((r.seconds or 0) / 3600) * 10 + 0.5) / 10,
                licenses = {}, records = {}, promotions = {}
            }
            if r.note and r.note ~= '' then e.note = { html = r.note, by = r.note_by or '—', at = r.note_at or '' } end
            for _, l in ipairs(lic[r.identifier] or {}) do e.licenses[#e.licenses + 1] = { id = l.license, at = l.at } end
            for _, c in ipairs(rec[r.identifier] or {}) do
                e.records[#e.records + 1] = { id = c.id, kind = c.kind, by = c.by_name, reason = c.reason, at = c.at,
                    voided = c.void_by and { by = c.void_by, at = c.void_at, reason = c.void_reason } or nil }
            end
            for _, p in ipairs(pro[r.identifier] or {}) do
                e.promotions[#e.promotions + 1] = { from = p.from_grade, to = p.to_grade, by = p.by_name, reason = p.reason, at = p.at }
            end
            employess[#employess + 1] = e
            e._identifier = r.identifier
        end
    end
    for _, id in ipairs(missing) do   -- pracownicy zatrudnieni poza bossmenu – dopisz z datą „dziś”
        MySQL.insert('INSERT IGNORE INTO bossmenu_members (identifier, job) VALUES (?, ?)', { id, job })
    end
    for _, e in ipairs(employess) do e._identifier = nil end
    return employess
end

function data.getBossmenuData(job)
    bossmenuData.employess = data.getEmployeeData(job)
    return bossmenuData
end

return data