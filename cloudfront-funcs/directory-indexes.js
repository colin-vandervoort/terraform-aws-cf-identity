function handler(event) {
  var request = event.request
  var olduri = request.uri;
  var newuri = olduri.replace(/\/$/, '\/index.html');
  event.request.uri = newuri
  return request
}