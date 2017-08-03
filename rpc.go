package main

import (
	"sync"

	"go.uber.org/zap"

	"github.com/kolo/xmlrpc"
)

func createPool(endpoint string) sync.Pool {
	return sync.Pool{New: func() interface{} {
		cli, err := xmlrpc.NewClient(endpoint, nil)
		if err != nil {
			panic("Failed to connect to URI while creating client")
		}

		return &RPCTranslate{Client: cli}
	}}
}

// RPCPool is a goroutine-safe wrapper around
// RPCTranslate objects. These are not thread safe
// because the underlying xmlrpc lib uses some non-thread
// safe behaviors.
type RPCPool struct {
	Endpoint string
	pool     sync.Pool
}

// NewRPCPool creates a new RPCPool object and sets up a pool for it
// given an endpoint
func NewRPCPool(endpoint string) *RPCPool {
	client, clientErr := xmlrpc.NewClient(endpoint, nil)
	if clientErr != nil {
		panic("couldn't connect to RPC endpoint")
	}
	client.Close()

	return &RPCPool{Endpoint: endpoint, pool: createPool(endpoint)}
}

// Translate is a thread-safe wrapper around Translate
// from the RPCTranslate object
func (p *RPCPool) Translate(text string) (string, error) {
	cli := p.pool.Get().(*RPCTranslate)
	defer p.pool.Put(cli)

	return cli.Translate(text)
}

// RPCTranslate wraps the XMLRPC client
type RPCTranslate struct {
	*xmlrpc.Client
}

// RPCTranslateMessage wraps
type RPCTranslateMessage struct {
	Text string `xmlrpc:"text"`
}

// Translate calls the translate rpc server
func (client *RPCTranslate) Translate(in string) (string, error) {
	result := &RPCTranslateMessage{}
	send := RPCTranslateMessage{Text: in}

	translateCall := client.Go("translate", send, result, nil)
	resultCall := <-translateCall.Done
	if resultCall.Error != nil {
		log.Error("Error from RPC call", zap.Error(resultCall.Error))
		return "", resultCall.Error
	}

	return result.Text, nil
}
