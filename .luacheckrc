-- Luacheck configuration file
globals = {
  "vim",
}

read_globals = {
  "describe",
  "it",
  "before_each",
  "after_each",
  "assert",
  "done",
}

ignore = {
  "631", -- Line is too long
}

files["tests/"] = {
  std = "+busted",
}