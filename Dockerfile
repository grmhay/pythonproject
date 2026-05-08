FROM python:3.13-slim AS builder

WORKDIR /build

COPY pyproject.toml README.md ./
COPY zamazingo/ zamazingo/

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir build && \
    python -m build --wheel


FROM python:3.13-slim

WORKDIR /app

COPY --from=builder /build/dist/*.whl ./

RUN pip install --no-cache-dir *.whl && \
    rm -f *.whl

ENTRYPOINT ["zamazingo"]
