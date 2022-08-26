set api
start cmd /k "cd %api% & uvicorn boaviztapi.main:app --host=localhost --port 8000"
set interface
start cmd /k "cd %interface% & flask run --reload"
start http://localhost:5000