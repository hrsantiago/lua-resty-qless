local cjson = require "cjson"
local qless = require "resty.qless"

local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local ngx_ERR = ngx.ERR
local ngx_now = ngx.now
local ngx_timer_at = ngx.timer.at
local cjson_encode = cjson.encode
local cjson_decode = cjson.decode
local co_yield = coroutine.yield


local _M = {
    _VERSION = '0.01',
}

local mt = { __index = _M }


function _M.new(params)
    return setmetatable({ params = params }, mt)
end


function _M.start(self, work, options)
    local function worker(premature)
        if not premature then
            local q = qless.new(self.params)
            local queue = q.queues[options.queues[1]]
            repeat
                local job = queue:pop()
                if job then
                    local res = job:perform(work)
                    if res then
                        job:complete()
                    else
                       -- job:fail()
                    end
                end
                co_yield() -- The scheduler will resume us.
            until not job

            local ok, err = ngx_timer_at(options.interval or 10, worker)
            if not ok then
                ngx_log("failed to run worker: ", err)
            end
        end
    end

    local ok, err = ngx_timer_at(0, worker)
    if not ok then
        ngx_log("failed to start worker: ", err)
    end
end


return _M
