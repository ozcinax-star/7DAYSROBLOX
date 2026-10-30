--!strict
-- Per-player token bucket. Every client -> server remote handler checks one before doing work.

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		ratePerSecond: number,
		buckets: { [Player]: { tokens: number, updatedAt: number } },
	},
	RateLimiter
))

function RateLimiter.new(ratePerSecond: number): RateLimiter
	local self = setmetatable({
		ratePerSecond = ratePerSecond,
		buckets = {},
	}, RateLimiter)
	Players.PlayerRemoving:Connect(function(player)
		self.buckets[player] = nil
	end)
	return self
end

-- Returns true and consumes a token if the player is under the limit.
function RateLimiter.allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if bucket == nil then
		bucket = { tokens = self.ratePerSecond, updatedAt = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(self.ratePerSecond, bucket.tokens + (now - bucket.updatedAt) * self.ratePerSecond)
	bucket.updatedAt = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return RateLimiter
