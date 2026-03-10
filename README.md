# purchase_log

if on windows:

In order to test the auto form filler, follow these steps:
1) open power shell and run the following commands
    irm https://ollama.com/install.ps1 | iex
    ollama pull mistral
    pip install ollama
    ollama serve
    ollama run mistral
2) open another terminal and run 
    uvicorn backend:app --reload
3) open another terminal and finally run
    flutter run -d chrome

Eventually the backend.py and the LLM will run non-locally (i.e. on server or with API service)
