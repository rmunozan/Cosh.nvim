local M = {}
local uv = vim.loop

local allowed_exts = require("cosh.allowed_exts")
local ignore_patterns = require("cosh.ignore_patterns")

-- Normalize Windows paths to Unix style
local function normalize(path)
	return path:gsub("\\", "/")
end

-- Current project root 
local function project_root()
	local cwd = uv.fs_realpath(vim.loop.cwd())
	return cwd and normalize(cwd) or ""
end

-- Build a path relative to the current root, if possible
local function relative_path(path)
	local root = project_root()
	local p = normalize(path)
	if root ~= "" and p:sub(1, #root + 1) == root .. "/" then
		return p:sub(#root + 2)
	end
	return p
end

-- Determine if `path` should be ignored
local function matches_ignore(path)
	local p = normalize(path)
	local rel = relative_path(p)
	local segments = {}
	for seg in rel:gmatch("[^/]+") do
		segments[#segments + 1] = seg
	end
	local basename = segments[#segments] or rel

	for _, raw in ipairs(ignore_patterns) do
		local pat = normalize(raw)
		local anchored = pat:sub(1, 1) == "/"
		local dir_only = pat:sub(-1) == "/"
		pat = pat:gsub("^/", ""):gsub("/$", "")

		-- extension ignore (".log" style)
		if pat:sub(1, 1) == "." and not dir_only then
			if basename:sub(-#pat) == pat then
				return true
			end

		elseif dir_only then
			-- directory match
			if anchored then
				if segments[1] == pat then
					return true
				end
			else
				for _, seg in ipairs(segments) do
					if seg == pat then
						return true
					end
				end
			end

		else
			-- plain filename or full relative path
			if anchored then
				if rel == pat then
					return true
				end
			else
				if basename == pat then
					return true
				end
			end
		end
	end

	return false
end

-- Extract and lowercase file extension
local function get_extension(path)
	return (path:match("^.+(%..+)$") or ""):lower()
end

-- Is this extension in our allowed list?
local function is_allowed(path)
	return allowed_exts[get_extension(path)] ~= nil
end

-- Get the code‑block prefix for this file
local function get_prefix(path)
	return allowed_exts[get_extension(path)]
end

-- Read entire file into a string
local function open_file(path)
	local fd, err = uv.fs_open(path, "r", 438)
	if not fd then return nil, "Failed to open file: " .. err end
	local stat, serr = uv.fs_fstat(fd)
	if not stat then uv.fs_close(fd) return nil, "Failed to stat file: " .. serr end
	local data, rerr = uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	if not data then return nil, "Failed to read file: " .. rerr end
	return data
end

-- Grab the current visual selection (To fix, right now does not validate if visual mode is on)
local function get_visual_selection()
	-- local mode = vim.api.nvim_get_mode().mode
	-- if not mode:match("[vV]") then
	-- 	return ""
	-- end
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
	if #lines == 0 then return "" end

	if #lines == 1 then
		lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
	else
		lines[1] = lines[1]:sub(start_pos[3])
		lines[#lines] = lines[#lines]:sub(1, end_pos[3])
	end

	return table.concat(lines, "\n")
end

-- Async walk for directory contents (non‑recursive, queue based)
local function walk_directory_async(root_dir, results, done_cb)
	results = results or {}
	local queue = { root_dir }

	local function step()
		local dir = table.remove(queue)
		if not dir then
			return done_cb(results)
		end

		local handle = uv.fs_scandir(dir)
		if handle then
			while true do
				local name, t = uv.fs_scandir_next(handle)
				if not name then break end
				local full = dir .. "/" .. name
				if not matches_ignore(full) then
					if t == "directory" then
						queue[#queue + 1] = full
					elseif t == "file" and is_allowed(full) then
						results[#results + 1] = full
					end
				end
			end
		end
		vim.defer_fn(step, 0)
	end

	step()
end

-- Build a visual tree of `path`
local function build_tree(path, prefix, lines)
	lines = lines or {}
	if matches_ignore(path) then
		return lines
	end
	local handle = uv.fs_scandir(path)
	if not handle then
		return lines
	end

	local entries = {}
	while true do
		local name, t = uv.fs_scandir_next(handle)
		if not name then break end
		local full = path .. "/" .. name
		if not matches_ignore(full) then
			entries[#entries + 1] = { name = name, type = t }
		end
	end

	table.sort(entries, function(a, b) return a.name < b.name end)

	for i, ent in ipairs(entries) do
		local last = (i == #entries)
		local branch = last and "└── " or "├── "
		lines[#lines + 1] = prefix .. branch .. ent.name
		if ent.type == "directory" then
			local ext = last and "    " or "│   "
			build_tree(path .. "/" .. ent.name, prefix .. ext, lines)
		end
	end

	return lines
end

-- Copy a single file to clipboard as a markdown code block
function M.copy_file_disk(path)
	if not is_allowed(path) or matches_ignore(path) then
		return vim.notify("Skipping file (not allowed or ignored): " .. path, vim.log.levels.WARN)
	end

	local content, err = open_file(path)
	if not content then
		return vim.notify(err, vim.log.levels.ERROR)
	end

	local prefix = get_prefix(path) or ""
	local formatted = "# " .. relative_path(path) .. "\n\n```" .. prefix .. "\n" .. content .. "\n```\n"
	vim.fn.setreg("+", formatted)
	vim.notify("Copied file from disk to clipboard: " .. path, vim.log.levels.INFO)
end

-- Copy entire buffer to clipboard
function M.copy_file_buffer(path)
	local bufnr
	local display_path

	if not path or path == "" or path == "%" then
		bufnr = 0
		display_path = vim.fn.expand("%:.")
	else
		bufnr = vim.fn.bufnr(path, false)
		if bufnr == -1 then
			return vim.notify("No open buffer for: " .. path, vim.log.levels.WARN)
		end
		display_path = path
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local content = table.concat(lines, "\n")
	local prefix = get_prefix(display_path) or ""
	local formatted = "# " .. relative_path(display_path) .. "\n\n```" .. prefix .. "\n" .. content .. "\n```\n"
	vim.fn.setreg("+", formatted)
	vim.notify("Copied buffer content from: " .. display_path, vim.log.levels.INFO)
end


-- Copy visual selection to clipboard
function M.copy_selection()
	local sel = get_visual_selection()
	if sel == "" then
		return vim.notify("No visual selection detected", vim.log.levels.WARN)
	end
	local path = vim.fn.expand("%:.")
	if not is_allowed(path) or matches_ignore(path) then
		return vim.notify("Skipping selection (file not allowed or ignored): " .. path, vim.log.levels.WARN)
	end

	local prefix = get_prefix(path) or ""
	local formatted = "# " .. relative_path(path) .. "\n\n```" .. prefix .. "\n" .. sel .. "\n```\n"
	vim.fn.setreg("+", formatted)
	vim.notify("Copied visual selection from: " .. path, vim.log.levels.INFO)
end

-- Copy entire directory contents as markdown code blocks
function M.copy_directory(dir)
	vim.notify("Scanning directory: " .. dir, vim.log.levels.INFO)
	walk_directory_async(dir, {}, function(files)
		if #files == 0 then
			return vim.notify("No valid files found in: " .. dir, vim.log.levels.WARN)
		end

		local collected = {}
		for _, p in ipairs(files) do
			local content, err = open_file(p)
			if content then
				local prefix = get_prefix(p) or ""
				collected[#collected + 1] = "# " .. relative_path(p) .. "\n\n```" .. prefix .. "\n" .. content .. "\n```\n"
			else
				vim.notify("Skipped " .. p .. ": " .. err, vim.log.levels.WARN)
			end
		end

		vim.fn.setreg("+", table.concat(collected, "\n\n"))
		vim.notify("Directory contents copied to clipboard: " .. dir, vim.log.levels.INFO)
	end)
end

-- Copy a visual tree of the directory to clipboard
function M.copy_dir_tree(dir)
	local header = vim.fn.fnamemodify(dir, ":t")
	local lines = { header }
	build_tree(dir, "", lines)
	vim.fn.setreg("+", table.concat(lines, "\n"))
	vim.notify("Copied directory tree for: " .. dir, vim.log.levels.INFO)
end

-- Allow users to extend allowed extensions or ignore patterns
function M.setup(opts)
	opts = opts or {}
	if opts.allow then
		for ext, prefix in pairs(opts.allow) do
			allowed_exts[ext] = prefix
		end
	end
	if opts.ignore then
		for _, pat in ipairs(opts.ignore) do
			ignore_patterns[#ignore_patterns + 1] = pat
		end
	end
end

return M
