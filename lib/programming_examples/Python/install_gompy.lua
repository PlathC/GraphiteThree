-- Lua

--------------------------------------------------------------
-- Declares Graphite function to the Python interpreter
--  (then Graphite functions can be used from standalone
--   Python and from Jupyter)
--------------------------------------------------------------

require('io')

if console_gui ~= nil then
   console_gui.show()
end

-- Query libraries directory and gompy lib name from Graphite
--------------------------------------------------------------
gompy_dir = gom.get_environment_value('PROJECT_ROOT') .. '/' ..
            gom.get_environment_value('LIBRARIES_SUBDIRECTORY')

ext = gom.get_environment_value('DLL_EXTENSION')

-- On mac, we create a .so symlink (Python refuses to load .dylib files)
if ext == '.dylib'
   ext = '.so'
end

gompy_lib = gom.get_environment_value('DLL_PREFIX')..'gompy'..ext

-- Query python path from Python interpreter
--------------------------------------------
gom.interpreter('Python').execute([[
import sys
python_path = str(sys.path)
]],false,false)

python_path = gom.interpreter('Python').globals.python_path
python_path = python_path:gsub('\\\\','/')
python_path = python_path:gsub('[]\'\\[]','')


install_dir = nil

-- Find a local installation directory in Python path
-----------------------------------------------------
print('Python path (* local directories)')
print('---------------------------------')
for s in string.split(python_path,', ') do
  if(
     string.starts_with(s, gom.get_environment_value('HOME_DIRECTORY'))
     and not string.ends_with(s, '.zip')
     and not string.ends_with(s, '.ZIP')
  ) then
      print('* '..s)
      if install_dir == nil then
         install_dir = s
      end
  else
      print('  '..s)
  end
end
print('')

-- Generate the source of gompy.py
----------------------------------

path_to_gompy = gompy_dir
if not string.ends_with(path_to_gompy,'/') then
   path_to_gompy = path_to_gompy..'/'
end
if FileSystem.os_name() == 'Windows' then
   path_to_gompy = path_to_gompy:gsub('/','\\\\')
end

if install_dir == nil then
    gom.err('Did not find any installation directory in your home')
    gom.err('You need to add a subdirectory of your home in PYTHONPATH and retry')
else
   print('Installing gompy.py in '..install_dir)
   F = io.open(install_dir..'/gompy.py','w')
   F:write("# Automatically generated by install_gompy.lua\n")

-- Commented-out, old version using (deprecated) 'imp' module
--   F:write("import imp\n")
--   F:write("module = imp.load_dynamic(\n")
--   F:write("   'gompy',\n")
--   F:write("   '"..path_to_gompy..gompy_lib.."'\n")
--   F:write(")\n")

-- New version using 'importlib'
   F:write("import importlib.util\n")
   F:write("spec=importlib.util.spec_from_file_location(\n")
   F:write("   'gompy',\n")
   F:write("   '"..path_to_gompy..gompy_lib.."'\n")
   F:write(")\n")

   F:write("module=importlib.util.module_from_spec(spec)\n")
   F:write("spec.loader.exec_module(module)\n")

   F:write("module.interpreter().set_environment_value(\n")
   F:write("   'OGF_PATH',\n")
   F:write("   '"..gom.get_environment_value('OGF_PATH').."'\n")
   F:write(")\n")

   F:write("module.interpreter().set_environment_value(\n")
   F:write("   'LIBRARIES_SUBDIRECTORY',\n")
   F:write("   '"..gom.get_environment_value('LIBRARIES_SUBDIRECTORY').."'\n")
   F:write(")\n")

   F:write("module.interpreter().append_dynamic_libraries_path(\n")
   F:write("   '"..path_to_gompy.."'\n")
   F:write(")\n")

   local plugins =
         gom.get_environment_value('base_modules')..';'..
         gom.get_environment_value('loaded_dynamic_modules')
   for plugin in string.split(plugins,';') do
      if plugin ~= 'gompy' then
         F:write("module.interpreter().load_module(")
         F:write("'"..plugin.."'")
         F:write(")\n")
      end
   end

   io.close(F)
end
