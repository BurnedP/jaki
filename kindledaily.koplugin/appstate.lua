--[[--
Tiny shared flag tracking whether the dashboard is currently shown, so we
never stack two instances (e.g. auto-start and auto-return firing close
together). Module state persists for the KOReader session.
--]]

return { open = false }
