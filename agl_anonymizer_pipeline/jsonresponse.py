import json

def json_response(boxes, status=200):
    return JsonResponse(data, status=status)