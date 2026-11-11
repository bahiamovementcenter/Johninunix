# Contracts for a Johnny.Decimal system, and what is built from it. Declare
# your system in system.ncl; `project` checks it and returns:
#
#   config      the config.json that jd reads, version 2 (`jd write-config` writes it)
#   scaffold    the areas, categories and IDs it declares (`jd scaffold`)
#   extensions  your extensions, checked against the pinned jd
#   adapters    the built-in adapters, and the functions an adapter defines
#
# Hand-written. The files in generated/ are not: they come from jd's source.
let generated = {
  upstream = import "generated/upstream.ncl",
  functions = import "generated/functions.ncl",
  commands = import "generated/commands.ncl",
  adapters = import "generated/adapters.ncl",
}
in

# A contract from a function that returns a list of error messages
let validator = fun check =>
  std.contract.from_validator (fun value =>
    let errors = check value in
    if errors == [] then 'Ok else 'Error { message = std.string.join "\n" errors }
  )
in
let matches = fun regex s => std.string.is_match regex s in
let digit = fun s i => std.string.substring i (i + 1) s in
let duplicates = fun xs =>
  (std.array.fold_left
    (fun acc x =>
      if std.array.elem x acc.seen then
        { seen = acc.seen, dup = acc.dup @ [x] }
      else
        { seen = acc.seen @ [x], dup = acc.dup }
    )
    { seen = [], dup = [] }
    xs
  ).dup
in

# The IDs every category reserves (johnnydecimal.com/documentation/the-standard-zeros).
# .06 to .08 are reserved for expansion and have no name.
let standard_zeros = {
  "00" = "JDex",
  "01" = "Inbox",
  "02" = "Task & project management",
  "03" = "Templates",
  "04" = "Links",
  "05" = "AI",
  "09" = "Archive",
}
in

let area_errors = fun areas =>
  areas
  |> std.record.to_array
  |> std.array.flat_map (fun { field = a, value = area } =>
    (if matches "^[0-9]0-[0-9]9$" a && digit a 0 == digit a 3 then [] else ["area '%{a}' is not a range like 10-19"])
    @ (
      std.record.get_or "categories" {} area
      |> std.record.to_array
      |> std.array.flat_map (fun { field = c, value = category } =>
        (if matches "^[0-9]{2}$" c && digit c 0 == digit a 0 then [] else ["category '%{c}' is not in area %{a}"])
        @ (
          std.record.get_or "ids" {} category
          |> std.record.fields
          |> std.array.flat_map (fun i =>
            if !(matches "^[0-9]{2}\\.[0-9]{2}$" i) || std.string.substring 0 2 i != c then
              ["ID '%{i}' is not in category %{c}"]
            else if std.array.elem (std.string.substring 3 5 i) ["06", "07", "08"] then
              ["ID '%{i}': .06 to .08 are reserved by the standard zeros"]
            else
              []
          )
        )
      )
    )
  )
in

let Category = {
  name | String,
  ids | doc "ID → name, like \"11.11\" = \"Passport\"" | { _ | String } | default = {},
}
in
let Area = {
  name | String,
  categories | { _ | Category } | default = {},
}
in
# An app name, as jd 5 accepts one: it names lib/adapters/<kind>/<app>.sh
let app_name = validator (fun a =>
  if std.is_string a && matches "^[a-z0-9_-]+$" a then [] else ["an app is a name of a-z, 0-9, _ and -, like obsidian"]
)
in
# Where the JDex is (jd's config version 2): a folder, an app, or both. An
# app with a JDex store (lib/adapters/jdex/, like bear and org) keeps the
# JDex itself; any other app is a folder of Markdown notes.
let Jdex = {
  app | doc "The note app: obsidian, bear, org, or one in extensions/adapters/notes/" | app_name | optional,
  path | doc "The folder of JDex notes, or for org, the Org file. A relative path is relative to system.ncl" | String | optional,
  vault | doc "The Obsidian vault's name" | String | optional,
}
in
let jdex_errors = fun j =>
  if std.record.has_field "path" j || (std.record.has_field "app" j && j.app == "bear") then
    []
  else
    ["a jdex needs a path, unless its app is bear"]
in
let Tasks = {
  app | doc "The task app: things, none, or one in extensions/adapters/tasks/" | app_name,
  source | doc "The template project's ID in the app" | String | optional,
  ..
}
in
let System = {
  sys
    | doc "A letter and two digits, like P76"
    | validator (fun s => if std.is_string s && matches "^[A-Z][0-9]{2}$" s then [] else ["a system id is a letter and two digits, like P76"]),
  title | String,
  root | doc "The system's folder. A relative path is relative to system.ncl" | String,
  jdex | doc "Where the JDex is, like { path = \"jdex\" } or { app = \"bear\" }" | Jdex | validator jdex_errors | optional,
  default | Bool | default = false,
  standard_zeros | doc "Add .00 to .05 and .09 to every category" | Bool | default = true,
  work_packages
    | {
      tasks | Tasks | optional,
      first_number
        | doc "The lowest W number jd gives a work package: 10 leaves W0000 to W0009 to the area. jd never gives W0003 or W0009"
        | validator (fun n => if std.is_number n && std.number.is_integer n && n >= 1 && n <= 9999 then [] else ["first_number is a whole number from 1 to 9999"])
        | optional,
    }
    | optional,
  areas | doc "Range → area, like \"10-19\"" | { _ | Area } | validator area_errors,
}
in

let Function = validator (fun f =>
  if std.array.elem f generated.functions then
    []
  else
    ["'%{f}' is not a function in jd %{generated.upstream.version}"]
)
in
let Command = validator (fun c =>
  if !(matches "^[a-z][a-z0-9-]*$" c) then
    ["command '%{c}' is not a lower-case word"]
  else if std.array.elem c generated.commands then
    ["command '%{c}' is built into jd"]
  else
    []
)
in
let Extension = {
  description | String,
  wraps | doc "jd functions it wraps with jd_wrap" | Array Function | default = [],
  commands | doc "Commands it adds with jd_command" | Array Command | default = [],
}
in
let extension_errors = fun extensions =>
  let all = fun field => extensions |> std.record.values |> std.array.flat_map (fun e => std.record.get_or field [] e) in
  (duplicates (all "wraps") |> std.array.map (fun f => "two extensions wrap %{f}"))
  @ (duplicates (all "commands") |> std.array.map (fun c => "two extensions add the command '%{c}'"))
  @ (
    extensions
    |> std.record.fields
    |> std.array.filter (fun f => !(matches "^[A-Za-z0-9_.-]+\\.sh$" f))
    |> std.array.map (fun f => "extension '%{f}' is not the name of a .sh file in extensions/")
  )
in
let system_errors = fun systems =>
  (if std.array.length systems == 0 then ["declare at least one system"] else [])
  @ (duplicates (std.array.map (fun s => s.sys) systems) |> std.array.map (fun s => "system %{s} is declared twice"))
  @ (
    if std.array.length (std.array.filter (fun s => std.record.get_or "default" false s) systems) > 1 then
      ["more than one system is the default"]
    else
      []
  )
in
let Project = {
  systems | Array System | validator system_errors,
  extensions | doc "File in extensions/ → what it does" | { _ | Extension } | validator extension_errors | default = {},
}
in

let config_of = fun s =>
  { sys = s.sys, title = s.title, root = s.root, default = s.default }
  & (if std.record.has_field "jdex" s then { jdex = s.jdex } else {})
  & (
    if std.record.has_field "work_packages" s then
      let w = s.work_packages in
      {
        workPackages =
          (if std.record.has_field "tasks" w then { tasks = w.tasks } else {})
          & (if std.record.has_field "first_number" w then { firstNumber = w.first_number } else {}),
      }
    else
      {}
  )
in
# A category's IDs, with the standard zeros it doesn't name itself
let ids_of = fun s c category =>
  let zeros =
    if s.standard_zeros then
      standard_zeros
      |> std.record.to_array
      |> std.array.map (fun { field = n, value = name } => { field = "%{c}.%{n}", value = name })
      |> std.record.from_array
      |> std.record.filter (fun i _ => !(std.record.has_field i category.ids))
    else
      {}
  in
  zeros & category.ids
in
let scaffold_of = fun s =>
  s.areas
  |> std.record.to_array
  |> std.array.flat_map (fun { field = a, value = area } =>
    let area_dir = "%{a} %{area.name}" in
    [{ kind = "area", path = area_dir }]
    @ (
      area.categories
      |> std.record.to_array
      |> std.array.flat_map (fun { field = c, value = category } =>
        let category_dir = "%{area_dir}/%{c} %{category.name}" in
        [{ kind = "category", path = category_dir }]
        @ (
          ids_of s c category
          |> std.record.to_array
          |> std.array.map (fun { field = i, value = name } => { kind = "id", path = "%{category_dir}/%{i} %{name}" })
        )
      )
    )
  )
  |> std.array.map (fun entry => entry & { sys = s.sys })
in

{
  zeros = standard_zeros,
  project = fun declared =>
    let p = declared | Project in
    {
      config = { version = 2, systems = std.array.map config_of p.systems },
      scaffold = std.array.flat_map scaffold_of p.systems,
      extensions = p.extensions,
      jd = generated.upstream,
      adapters = generated.adapters,
    },
}
