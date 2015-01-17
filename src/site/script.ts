///<reference path="../../build/typings/tsd.d.ts" />

interface Elm {
  RemoteModel: ElmModule<RemoteModelPorts>;
}

interface RemoteModelPorts {
  bookUrls: PortFromElm<Array<string>>;
  bookFeed: PortToElm<FireElm.Data>;
  writerUrls: PortFromElm<Array<string>>;
  writerFeed: PortToElm<FireElm.Data>;
}

window.onload = () => {
  var component = Elm.fullscreen(Elm.RemoteModel, {
    bookFeed: null,
    writerFeed: null
  });
  FireElm.readData(component.ports.bookUrls, component.ports.bookFeed);
  FireElm.readData(component.ports.writerUrls, component.ports.writerFeed);
}