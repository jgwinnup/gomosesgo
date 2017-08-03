#!/usr/bin/env python3
from xmlrpc.server import SimpleXMLRPCServer
from xmlrpc.server import SimpleXMLRPCRequestHandler

import logging

logger = logging.getLogger(__name__)
# Restrict to a particular path.
class RequestHandler(SimpleXMLRPCRequestHandler):
    rpc_paths = ('/RPC2',)

def translate(x):
    return x

def run():
    server = SimpleXMLRPCServer(("localhost", 22234),
                                requestHandler=RequestHandler,
                                logRequests=False)
    server.register_introspection_functions()
    server.register_function(translate, 'translate')
    # Run the server's main loop
    server.serve_forever()

if __name__ == "__main__":
    logger.info("Running as an app")
    run()
