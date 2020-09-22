package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"

	"github.com/joncrlsn/dque"
	"github.com/stratoberry/go-gpsd"
)

const url = "https://ingest.jrcichra.dev"

//gpsRecord - a basic GPS datapoint
type gpsRecord struct {
	Value gpsd.TPVReport
}

// gpsRecordBuilder - abstracts out a GPSRecord for dque to work
func gpsRecordBuilder() interface{} {
	return &gpsRecord{}
}

func makeQueue() *dque.DQue {
	qName := "gps_queue"
	qDir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	fmt.Println("qDir=", qDir)
	segmentSize := 50
	if err != nil {
		panic(err)
	}
	q, err := dque.NewOrOpen(qName, qDir, segmentSize, gpsRecordBuilder)
	if err != nil {
		panic(err)
	}
	return q
}

func makeGPS(hostname string, port int) *gpsd.Session {
	gps, err := gpsd.Dial(hostname + ":" + strconv.Itoa(port))
	if err != nil {
		panic(err)
	}
	return gps
}

func tpvToString(tpv *gpsd.TPVReport) string {
	b, err := json.Marshal(tpv)
	if err != nil {
		panic(err)
	}
	return string(b)
}

func queueToPost(q *dque.DQue, h *http.Client) {
	// Only dequeue if we could successfully POST
	var tpv interface{}
	var err error

	if tpv, err = q.PeekBlock(); err != nil {
		if err != dque.ErrEmpty {
			log.Fatal("Error dequeuing item ", err)
		}
	}

	// Convert it to JSON and post
	json := []byte(tpvToString(tpv.(*gpsd.TPVReport)))
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(json))
	req.Header.Set("Content-Type", "application/json")
	if err != nil {
		panic(err)
	}

	resp, err := h.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

	fmt.Println("response Status:", resp.Status)
	fmt.Println("response Headers:", resp.Header)
	body, _ := ioutil.ReadAll(resp.Body)
	fmt.Println("response Body:", string(body))

	// Dequeue this variable now
	_, err = q.Dequeue()
	if err != nil {
		panic(err)
	}
}

func main() {
	//connect to gps
	gps := makeGPS("localhost", 2947)
	q := makeQueue()
	h := &http.Client{}
	// Handle sending off HTTP posts
	go queueToPost(q, h)
	// GPS loop
	gps.AddFilter("TPV", func(r interface{}) {
		// This anon function is called every time a new TPV value comes in, scoped this way so we can use q easily
		tpv := r.(*gpsd.TPVReport)
		fmt.Println("Location inserted into file queue:", tpvToString(tpv))
	})
	done := gps.Watch()
	<-done
}
