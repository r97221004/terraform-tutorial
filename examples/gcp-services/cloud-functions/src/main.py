import functions_framework


@functions_framework.http
def hello_http(request):
    name = request.args.get("name", "world")
    return f"Hello, {name}!\n"


@functions_framework.cloud_event
def on_upload(cloud_event):
    data = cloud_event.data
    print(f"New file: gs://{data['bucket']}/{data['name']} ({data['size']} bytes)")
