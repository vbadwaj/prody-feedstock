"%PYTHON%" setup.py build_ext --inplace --force
if errorlevel 1 exit 1

"%PYTHON%" -m pip install -Ue .
if errorlevel 1 exit 1