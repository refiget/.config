function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	local size = self._file:size()
	local time_str = ""

	if time > 0 then
		if os.date("%Y", time) == os.date("%Y") then
			time_str = os.date("%b %d %H:%M", time)
		else
			time_str = os.date("%b %d  %Y", time)
		end
	end

	local size_str = size and ya.readable_size(size) or "-"
	return ui.Line(string.format("%s  %s", size_str, time_str))
end
