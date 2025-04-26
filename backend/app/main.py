from fastapi import FastAPI

app = FastAPI(
    #title = "Event Extraction API",
    #description = "Extrahiert Event-Informationen aus Bildern und erstellt .ics-Dateien.",
    #version = 1.0.0,
)

items = []

@app.get("/")
def root():
    return {"Hello": "World"}

@app.post("/items")
def create_item(item: str):
    #content = await file.read()
    items.append(item)
    return items

@app.get("/items/{item_id}")
def get_item(item_id: int) -> str:
    item = items[item_id]
    return item