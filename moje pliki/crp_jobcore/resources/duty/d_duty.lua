return {
    dutyDebug = false,
    -- Prace, którymi wolno przełączać służbę (wejście = off<job>, zejście = <job>).
    -- Dzięki tej liście praca typu „officer” nie zostanie potraktowana jak „off…”.
    jobs = { 'police', 'ambulance' },
    locations = {
        ['mrpd'] = {
            coords = vec4(449.5, -979.7, 30.6, 66.401458740234),
            jobs = {['police'] = 0, ['offpolice'] = 0}
        },
        ['hospital'] = {
            coords = vec4(1129.5780, -1544.2419, 34.8, 107.1895),
            jobs = {['ambulance'] = 0, ['offambulance'] = 0}
        }
    }
}