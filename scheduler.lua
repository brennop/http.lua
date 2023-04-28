-- taken from https://gist.github.com/Deco/1818054

local coroutine_scheduler = {
    _NAME = "coroutine_scheduler.lua",
    _VERSION = "1.0.0",
}

local unpack = unpack or table.unpack

local Scheduler
do Scheduler = setmetatable({}, {
        __call = function(class)
            return setmetatable({
                threads = {},
            }, class)
        end
    })
    Scheduler.__index = Scheduler
    function Scheduler:select()
        -- selects a coroutine from the list and runs it
        local time, shortest_wait_time = os.clock()
        for thread_i = 1, #self.threads do
            local thread = self.threads[thread_i]
            local state, ret = thread.state
            if state == "wait" then
                if time >= thread.resume_time then
                    thread.resume_time = nil
                    thread.state = "running"
                    table.remove(self.threads, thread_i)
                    ret = {coroutine.resume(thread.co, time-thread.suspend_time, unpack(thread.arg))}
                    thread.suspend_time = nil
                    thread.arg = nil
                elseif not shortest_wait_time or thread.resume_time < shortest_wait_time then
                    shortest_wait_time = thread.resume_time
                end
            elseif state == "suspend" then
                thread.state = "running"
                table.remove(self.threads, thread_i)
                ret = {coroutine.resume(thread.co, unpack(thread.arg))}
                thread.arg = nil
            elseif state == "new" then
                thread.state = "running"
                table.remove(self.threads, thread_i)
                ret = {coroutine.resume(thread.co, unpack(thread.arg))}
                thread.arg = nil
            end
            if ret then
                local act, worked = table.remove(ret, 2), table.remove(ret, 1)
                if worked then
                    local status = coroutine.status(thread.co)
                    if status == "dead" then
                        thread.state = "dead"
                    else
                        if act == "suspend" then
                            thread.arg = ret
                            thread.state = "suspend"
                            table.insert(self.threads, thread)
                        elseif act == "wait" then
                            local wait_val = table.remove(ret, 1)
                            local wait_time = tonumber(wait_val)
                            if not wait_time then
                                return false, "thread returned non-numeric wait time ("..tostring(wait_val)..")"
                            end
                            thread.arg = ret
                            thread.suspend_time = time
                            thread.resume_time = time+wait_time
                            thread.state = "wait"
                            table.insert(self.threads, 1, thread)
                        end
                    end
                else
                    return false, act
                end
                return true, 0
            end
        end
        if shortest_wait_time then
            return true, shorest_wait_time
        end
        return false, "no threads to select"
    end
    
    function Scheduler:spawn(func, ...)
        -- creates a new thread and adds it to the list (but does not run it straight away)
        table.insert(self.threads, {
            state = "new",
            co = coroutine.create(func),
            arg = {...},
        })
    end
    function Scheduler:run(func, ...)
        -- creates a new thread and adds it to the top of the list, and suspends the current thread
        table.insert(self.threads, 1, {
            state = "new",
            co = coroutine.create(func),
            arg = {...},
        })
        coroutine.yield("suspend")
    end
    
    function Scheduler:suspend(...)
        -- suspsends the current thread and adds it to the bottom of the list
        -- returns the arguments passed
        return coroutine.yield("suspend", ...)
    end
    function Scheduler:wait(time, ...)
        -- suspends the current thread and gives it a wait condition
        -- returns the actual time waited and the arguments passed
        return coroutine.yield("wait", time, ...)
    end
end
coroutine_scheduler.Scheduler = Scheduler

return coroutine_scheduler

