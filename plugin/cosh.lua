if vim.fn.has("nvim-0.7.0") ~= 1 then
	vim.api.nvim_err_writeln("Cosh.nvim requires at least nvim-0.7.0.")
end

local cosh = require("cosh")

-- Normalize file or dir input
local function resolve_path(raw)
	if not raw or raw == "%" then
		return vim.fn.expand("%:.")
	end
	return raw
end

local function resolve_dir(raw)
	if not raw or raw == "/" then
		return vim.fn.getcwd()
	elseif raw == "%" then
		return vim.fn.expand("%:p:h")
	end
	return raw
end

-- Main command dispatcher: :Cosh [file|buffer|selection|dir|tree] [target]
vim.api.nvim_create_user_command("Cosh", function(opts)
	local args = opts.fargs
	if #args < 1 then
		vim.notify("Usage: :Cosh [file|buffer|selection|dir|tree] [path]", vim.log.levels.ERROR)
		return
	end

	local kind = args[1]
	local target = args[2]

	if kind == "file" then
		local path = resolve_path(target)
		cosh.copy_file_disk(path)

	elseif kind == "buffer" then
		local path = resolve_path(target)
		cosh.copy_file_buffer(path)

	elseif kind == "selection" then
		cosh.copy_selection()

	elseif kind == "dir" then
		local dir = resolve_dir(target)
		cosh.copy_directory(dir)

	elseif kind == "tree" then
		local dir = resolve_dir(target)
		cosh.copy_dir_tree(dir)

	else
		vim.notify("Unknown Cosh action: " .. tostring(kind), vim.log.levels.WARN)
	end
end, {
	nargs = "+",
	desc = "Copy code or structure to clipboard: file, buffer, selection, dir, tree",
})
