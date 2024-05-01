FROM fedora AS builder

WORKDIR /root

RUN sed -e '$ainstall_weak_deps=False' -i /etc/dnf/dnf.conf && \
	dnf install -y \
		cargo \
		clang-devel \
		cmake \
		dbus-devel \
		git \
		libcap-devel \
		libdrm-devel \
		libepoxy-devel \
		libva-devel \
		make \
		mesa-libgbm-devel \
		meson \
		protobuf-compiler \
		wayland-protocols-devel \
		;

COPY aemu aemu

RUN cd aemu && \
	cmake \
		-DAEMU_COMMON_GEN_PKGCONFIG=ON \
		-DAEMU_COMMON_BUILD_CONFIG=gfxstream \
		-DENABLE_VKCEREAL_TESTS=OFF \
		-B build && \
	cmake --build build -j && \
	cmake --install build

COPY gfxstream gfxstream

RUN cd gfxstream && \
	meson setup -Ddefault_library=static build && \
	meson install -C build

COPY crosvm crosvm

RUN cd crosvm && \
	(sed -i 's/-Werror//' third_party/minigbm/common.mk || true) && \
	cargo fetch && \
	cargo --offline install \
		--path . \
		--root /usr/local \
		--features audio,balloon,config-file,gdb,gfxstream,gpu,net,pci-hotplug,qcow,registered_events,swap,tokio,usb,vaapi,video-decoder,video-encoder,virgl_renderer,vtpm,wl-dmabuf && \
	strip -s /usr/local/bin/crosvm

FROM fedora

RUN sed -e '$ainstall_weak_deps=False' -i /etc/dnf/dnf.conf && \
	dnf install -y \
		dbus-libs \
		libcap \
		libdrm \
		libepoxy \
		libva \
		libwayland-client \
		mesa-dri-drivers \
		mesa-libEGL \
		;

COPY --from=builder /usr/local/bin/crosvm /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/crosvm"]
