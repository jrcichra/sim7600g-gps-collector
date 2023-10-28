package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/joncrlsn/dque"
	"github.com/stratoberry/go-gpsd"
	"gopkg.in/yaml.v2"
)

type GPSDConfig struct {
	URL         string `json:"url"`
	Port        int    `json:"port"`
	TPVInterval int    `json:"tpv_interval"`
}

type IngestdConfig struct {
	URL               string   `json:"url"`
	Database          string   `json:"database"`
	Table             string   `json:"table"`
	AdditionalHeaders []string `json:"additional_headers"`
}

type Config struct {
	GPSDConfig    `json:"gpsd"`
	IngestdConfig `json:"ingestd"`
}

// gps record with hostname metadata
// jonathandbriggs: Added cputemp scraping for raspi.
type dbRecord struct {
	*gpsd.TPVReport
	Hostname string  `json:"hostname"`
	Cputemp  float64 `json:"cputemp"`
}

// dbRecordBuilder - abstracts out a dbRecord for dque to work
func dbRecordBuilder() interface{} {
	return &dbRecord{}
}

func makeQueue() *dque.DQue {
	qName := "gps_queue"
	qDir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	log.Println("qDir=", qDir)
	segmentSize := 50
	if err != nil {
		panic(err)
	}
	q, err := dque.NewOrOpen(qName, qDir, segmentSize, dbRecordBuilder)
	if err != nil {
		panic(err)
	}
	return q
}

func makeGPS(hostname string, port int) *gpsd.Session {
	gps, err := gpsd.DialTimeout(hostname+":"+strconv.Itoa(port), time.Second*5)
	if err != nil {
		panic(err)
	}
	return gps
}

func dbrToMap(dbr *dbRecord) map[string]interface{} {
	m := make(map[string]interface{})
	b, err := json.Marshal(dbr)

	if err != nil {
		panic(err)
	}
	err = json.Unmarshal(b, &m)
	if err != nil {
		panic(err)
	}
	return m
}

func queueToPost(q *dque.DQue, h *http.Client, cfg Config) {
	for {
		// Only dequeue if we could successfully POST
		var t interface{}
		var err error

		if t, err = q.PeekBlock(); err != nil {
			if err != dque.ErrEmpty {
				log.Fatal("Error dequeuing item ", err)
			}
		}

		// rename columns
		record := t.(*dbRecord)
		m := dbrToMap(record)
		tme := m["time"]
		delete(m, "time")
		m["gps_timestamp"] = tme
		b, err := json.Marshal(m)
		if err != nil {
			log.Println(err)
			continue
		}

		// parse time to Golang time for checks

		ttime, err := time.Parse(time.RFC3339, tme.(string))
		if err != nil {
			log.Println(err)
			continue
		}

		//Make sure lat/lon isn't zero & the time is at least reasonable. If it is bad data, skip it
		// log.Println("spew of m:")
		// spew.Dump(m)
		if m["lat"] == 0.0 || m["lon"] == 0.0 || ttime.Year() < time.Now().Year()-1 {
			// Dequeue this variable and skip
			log.Println("Found a bad lat+lon, skipping entry and dequeuing it")
			_, err = q.Dequeue()
			if err != nil {
				panic(err)
			}
			continue
		}

		log.Println("POSTING:", string(b))
		// post

		req, err := http.NewRequest("POST", cfg.IngestdConfig.URL+"/"+cfg.IngestdConfig.Database+"/"+cfg.IngestdConfig.Table, bytes.NewBuffer(b))
		if err != nil {
			log.Println(err)
			continue
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("User-Agent", "gps-collector")
		for _, header := range cfg.IngestdConfig.AdditionalHeaders {
			kv := strings.SplitN(header, "=", 2)
			req.Header.Set(kv[0], kv[1])
		}

		resp, err := h.Do(req)
		if err != nil {
			log.Println(err)
			continue
		}

		log.Println("response Status:", resp.Status)
		if resp.StatusCode == 200 {
			// Dequeue this variable now
			_, err = q.Dequeue()
			if err != nil {
				panic(err)
			}
		} else {
			log.Println("Not dequeuing because I didn't get a 200 OK")
		}
		resp.Body.Close()
	}
}

func main() {
	// parse the config file
	configPath := flag.String("config", "config.yaml", "path to config file")
	flag.Parse()

	configFile, err := os.ReadFile(*configPath)
	if err != nil {
		panic(err)
	}
	var cfg Config
	if err := yaml.Unmarshal(configFile, &cfg); err != nil {
		panic(err)
	}

	//connect to gps
	gps := makeGPS(cfg.GPSDConfig.URL, cfg.GPSDConfig.Port)
	q := makeQueue()
	h := &http.Client{}
	h.Timeout = time.Second * 20
	hostname, err := os.Hostname()
	log.Println("hostname=", hostname)
	if err != nil {
		panic(err)
	}
	// Handle sending off HTTP posts
	go queueToPost(q, h, cfg)
	// Ticker for only one TPV per interval
	ticker := time.NewTicker(time.Duration(cfg.GPSDConfig.TPVInterval) * time.Second)
	// GPS loop
	gps.AddFilter("TPV", func(r interface{}) {
		// This anon function is called every time a new TPV value comes in, scoped this way so we can use q easily
		select {
		case <-ticker.C:
			// Only enqueue if the ticker went off
			tpv := r.(*gpsd.TPVReport)
			// Include the CPU temp.
			tmp, _ := os.ReadFile(`/sys/class/thermal/thermal_zone0/temp`)
			// Trim the newline off the end of the CPU Temp.
			if len(tmp) > 0 {
				tmp = tmp[:len(tmp)-1]
			}
			// Convert the "Byte Slice Array thing" to a string
			tmpstr, _ := strconv.ParseFloat(string(tmp), 64)
			// Convert the string from "milliCelcius" to "Celcius" (I'm fully aware milli-celcius doesn't make sense.)
			tmpstr = tmpstr / 1000
			log.Println("tempstr", tmpstr)
			// Queue the record.
			dbr := &dbRecord{tpv, hostname, tmpstr}
			err := q.Enqueue(dbr)
			if err != nil {
				panic(err)
			}
		default:
			// Do nothing with the data
		}
		// log.Println("Location inserted into file queue:", string(dbrToBytes(dbr)))
	})
	done := gps.Watch()
	<-done
	log.Println("The program is ending because gps.Watch() came back. Hopefully this shouldn't happen")
}
