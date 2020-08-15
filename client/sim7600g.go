package main

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"

	"github.com/joncrlsn/dque"
	"github.com/stratoberry/go-gpsd"
)

//gpsRecord - a basic GPS datapoint
type gpsRecord struct {
	Value string
}

// gpsRecordBuilder - abstracts out a GPSRecord for dque to work
func gpsRecordBuilder() interface{} {
	return &gpsRecord{}
}

func makeQueue() *dque.DQue {
	qName := "gps_queue"
	qDir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	segmentSize := 50
	if err != nil {
		panic(err)
	}
	q, err := dque.New(qName, qDir, segmentSize, gpsRecordBuilder)
	if err != nil {
		panic(err)
	}
	return q
}

func makeUDP(hostname string, port int) net.Conn {
	conn, err := net.Dial("udp", hostname+":"+strconv.Itoa(port))
	if err != nil {
		panic(err)
	}
	return conn
}

func makeGPS(hostname string, port int) *gpsd.Session {
	gps, err := gpsd.Dial(hostname + ":" + strconv.Itoa(port))
	if err != nil {
		panic(err)
	}
	return gps
}

//Gets data from GPSD and processes it
func collectGPS(r interface{}) {
	report := r.(*gpsd.TPVReport)
	fmt.Println("Location updated", report.Lat, report.Lon)
}

func main() {
	//Get cli args
	// hostname := flag.String("hostname", "collector.example.com", "hostname/ip to send UDP packet to")
	// port := flag.Int("port", 33335, "port on hostname to send to")
	// flag.Parse()
	//connect to udp
	// conn := makeUDP(*hostname, *port)
	//connect to gps
	gps := makeGPS("localhost", 2947)
	gps.AddFilter("TPV", collectGPS)
	done := gps.Watch()
	<-done
	// conn.Write([]byte("hello\n"))
}
