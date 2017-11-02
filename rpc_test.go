package main

import (
	"testing"

	"github.com/kolo/xmlrpc"

	"go.uber.org/zap"
)

var (
	testLog, _ = zap.NewDevelopment()
)

const nItems = 100

func submitTestItem(t *testing.T, trans *RPCPool, itemsChan <-chan string, proccedChan chan<- string) {
	var localProcced int
	for {
		item, more := <-itemsChan
		if more {
			res, err := trans.Translate(item)
			if err != nil {
				t.Fatal(err)
			}
			if res != "world" {
				t.Errorf("did not get right string; instead got: %v when translating %v", res, item)
			}
			proccedChan <- res
			localProcced++
		} else {
			testLog.Info("Reached end of channel", zap.Int("n-procced", localProcced))
			break
		}
	}
}

const endpoint = "http://localhost:22234/RPC2"

func TestParallelRPCCalls(t *testing.T) {
	testLog.Info("Checking connectivity")
	client, clientErr := xmlrpc.NewClient(endpoint, nil)
	if clientErr != nil {
		panic("failed to connect to RPC")
	}
	client.Close()
	testLog.Info("Connected OK")

	itemsChan := make(chan string, nItems*4)
	proccedChan := make(chan string, nItems*4)

	for i := 0; i < nItems*4; i++ {
		itemsChan <- "world"
	}
	close(itemsChan)
	testLog.Info("Created and filled items channel")

	wrapper := NewRPCPool(endpoint)
	testLog.Info("RPC Pool created")
	for i := 0; i < 4; i++ {
		go submitTestItem(t, wrapper, itemsChan, proccedChan)
	}

	nProcced := 0
	for {
		_ = <-proccedChan
		nProcced++
		if nProcced%nItems == 0 {
			testLog.Info("Processing step", zap.Int("n-processed", nProcced))
		}
		if nProcced == nItems*4 {
			break
		}
	}

	if len(proccedChan) > 0 {
		t.Fatal("processed more than desired args")
	}
}
