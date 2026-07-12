local ffi = require("ffi")

local EV_ADD = 0x0001   
local EV_DELETE = 0x0002 
local EVFILT_READ = -1
local MAX_EVENTS = 32

ffi.cdef[[
struct kevent_t {
    uintptr_t       ident;
    int16_t         filter;
    uint16_t        flags;
    uint32_t        fflags;
    intptr_t        data;
    void            *udata;
};

int     kqueue(void);
int     kevent(int kq,
    const struct kevent_t *changelist, int nchanges,
    struct kevent_t *eventlist, int nevents,
    const struct timespec *timeout);
]]

local kqueue = {}

function kqueue:setup(server_fd)
  self.kq = ffi.C.kqueue()

  self.event = ffi.new("struct kevent_t[1]", {{
    ident = server_fd, 
    filter = -1,  -- EVFILT_READ,
    flags = 1,    -- EV_ADD
    fflags = 0,
    data = 0,
  }})

  local result = ffi.C.kevent(self.kq, self.event, 1, nil, 0, nil)
  assert(result == 0, "error while setting event")

  self.event_list = ffi.new("struct kevent_t[?]", MAX_EVENTS)
  self.change_list = ffi.new("struct kevent_t[?]", MAX_EVENTS)
  self.change_count = 0
end

function kqueue:poll()
  if self.change_count > 0 then
    ffi.C.kevent(self.kq, self.change_list, self.change_count, nil, 0, nil)
    self.change_count = 0
  end
  return ffi.C.kevent(self.kq, nil, 0, self.event_list, MAX_EVENTS, nil)
end

function kqueue:add(fd)
  self.change_list[self.change_count].ident = fd
  self.change_list[self.change_count].filter = EVFILT_READ
  self.change_list[self.change_count].flags = EV_ADD
  self.change_count = self.change_count + 1
end

return kqueue
