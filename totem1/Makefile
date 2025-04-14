EXE=totem1arm
EXE_MINI=totem1arm_g
EXE_MINI_64=totem1x64_g
GARBLE=$(HOME)/go/bin/garble
OUT_DIR=output/
FLAG=$(shell cat $(CURDIR)/flag.txt)
GOFLAGS=-trimpath -buildvcs=false -ldflags="-s -w -X main.Version=1.0.0"

all: test release

release: clean
	GOOS=linux GOARCH=amd64 $(GARBLE) -tiny -literals build $(GOFLAGS) -o  totem1-uploadme main.go

go:
	go build $(GOFLAGS) -o $(OUT_DIR)/$(EXE) main.go

garble:
	$(GARBLE) -tiny -literals build $(GOFLAGS) -o  $(OUT_DIR)/$(EXE_MINI) main.go
	GOOS=linux GOARCH=amd64 $(GARBLE) -tiny -literals build $(GOFLAGS) -o  $(OUT_DIR)/$(EXE_MINI_64) main.go

docker-build:
	docker buildx build --platform linux/amd64 -t totem-test -f $(CURDIR)/Dockerfile .

strings: garble
	strings -a $(OUT_DIR)/$(EXE) >  $(OUT_DIR)/$(EXE).txt
	strings -a $(OUT_DIR)/$(EXE_MINI) >  $(OUT_DIR)/$(EXE_MINI).txt
	strings -a $(OUT_DIR)/$(EXE_MINI_64) > $(OUT_DIR)/$(EXE_MINI_64).txt

#test: clean docker-build garble go
test:
	go test $(CURDIR)/totemvm
	@echo "Testing with input 'a'..."
	@docker run --platform linux/amd64 --rm -v $(CURDIR):/code totem-test bash -c "echo 'a' | /code/$(OUT_DIR)/$(EXE_MINI_64)" | grep "Sorry, that's not right." || (echo "❌ Test failed: Expected error message not found"; exit 1)
	@echo "✅ Test passed: Incorrect flag failed."

	@echo "Testing with FLAG input..."
	@docker run --platform linux/amd64 --rm -v $(CURDIR):/code totem-test bash -c "echo $(FLAG) | /code/$(OUT_DIR)/$(EXE_MINI_64)" | grep "Correct! You found the flag!" || (echo "❌ Test failed: Success message not found"; exit 1)
	@echo "✅ Test passed: Correct flag succeeded."

clean:
	docker rmi totem-test || true
	rm -f totem1* $(OUT_DIR)/*
