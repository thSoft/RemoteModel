///<reference path="../../build/typings/tsd.d.ts" />

interface Elm {
  RemoteModel: ElmModule<RemoteModelPorts>;
}

interface RemoteModelPorts {
  urls: PortFromElm<Array<string>>;
  feed: PortToElm<FireElm.Data>;
}

window.onload = () => {
  var component = Elm.fullscreen(Elm.RemoteModel, {
    feed: null
  });
  FireElm.readData(component.ports.urls, component.ports.feed);
}