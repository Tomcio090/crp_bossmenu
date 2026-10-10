return {
    dutyDebug = false,
    -- Prace, którymi wolno przełączać służbę (wejście = off<job>, zejście = <job>).
    -- Dzięki tej liście praca typu „officer” nie zostanie potraktowana jak „off…”.
    -- Dopisz tu każdą pracę, która ma służbę – dla każdej z nich potrzebny jest też
    -- punkt w `locations` niżej (albo własny sposób wchodzenia na służbę).
    -- `centra_autos` = firma dostawcy, z niej korzysta dostawa lawetą (nano_cd).
    jobs = { 'police', 'ambulance', 'centra_autos' },
    locations = {
        ['mrpd'] = {
            coords = vec4(449.5, -979.7, 30.6, 66.401458740234),
            jobs = {['police'] = 0, ['offpolice'] = 0}
        },
        ['hospital'] = {
            coords = vec4(1129.5780, -1544.2419, 34.8, 107.1895),
            jobs = {['ambulance'] = 0, ['offambulance'] = 0}
        },
        ['centra_autos'] = {
            coords = vec4(-924.9637, -1169.8820, 4.9501, 138.3062),
            jobs = {['centra_autos'] = 0, ['offcentra_autos'] = 0}
        }
    }
}
