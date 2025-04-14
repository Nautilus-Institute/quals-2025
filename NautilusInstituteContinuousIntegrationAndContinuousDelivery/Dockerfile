FROM nautilusinstitute.azurecr.io/elixir:latest as builder

WORKDIR /nicicd

COPY src/ /nicicd/src/

COPY *.ex* .

RUN elixirc nicicd.ex

RUN cd src && make

FROM shellweplayagame.azurecr.io/elixir:latest as runner

WORKDIR /nicicd

COPY --from=builder /nicicd/Elixir.NautilusInstituteContinuousIntegrationAndContinuousDelivery.beam .
COPY --from=builder /nicicd/Elixir.NautilusInstituteContinuousIntegrationAndContinuousDelivery.GitRepo.beam .
COPY --from=builder /nicicd/Elixir.NautilusInstituteContinuousIntegrationAndContinuousDelivery.Job.beam .
COPY --from=builder /nicicd/Elixir.NautilusInstituteContinuousIntegrationAndContinuousDelivery.JobDefinition.beam .
COPY --from=builder /nicicd/Elixir.NautilusInstituteContinuousIntegrationAndContinuousDelivery.JobLoader.beam .
COPY --from=builder /nicicd/Elixir.NautilusInstituteContinuousIntegrationAndContinuousDelivery.JobRegistry.beam .
COPY --from=builder /nicicd/Elixir.NautilusInstituteContinuousIntegrationAndContinuousDelivery.JobRunner.beam .

COPY ./app_main /nicicd/app
COPY ./common_jobs /nicicd/common_jobs
COPY process_git_repo.exs /nicicd/process_git_repo.exs
COPY src/secrets /bin/secrets

COPY src/run_challenge.sh /nicicd/run_challenge.sh
COPY src/server.py /nicicd/server.py

RUN mkdir -p /ci/ && chmod 777 /ci/
RUN mkdir -p /releases/ && chmod 777 /releases/
RUN mkdir -p /pr-status/ && chmod 777 /pr-status/

RUN adduser --no-create-home --disabled-password --gecos "" secrets
RUN mkdir /secrets/ && \
    echo "flug{you-connected-to-the-wrong-endpoint-for-flag2-please-try-the-other-endpoint-thank-you:)}" > /secrets/flag2 && \
    chown secrets -R /secrets && \
    chmod 500 /secrets/ && chmod 400 /secrets/flag2

RUN chown secrets /bin/secrets && \
    chmod 501 /bin/secrets && \
    chmod u+s /bin/secrets

RUN echo "flug{you-connected-to-the-wrong-endpoint-for-flag1-please-try-the-other-endpoint-thank-you:)}" > /flag1

RUN adduser --no-create-home --disabled-password --gecos "" user
USER user

CMD ["/nicicd/run_challenge.sh"]
