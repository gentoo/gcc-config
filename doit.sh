#!/bin/bash
# Convert ugly gcc-config cvs history into a sane git repo

set -e
shopt -s nullglob

g() {
	local cmd=$1; shift
	case ${cmd} in
	a)  cmd=add;;
	ci) cmd=commit;;
	fp) cmd=format-patch;;
	l)  cmd=log;;
	t)  cmd=tag;;
	esac
	git "${cmd}" "$@"
}

scrub_patch() {
	sed -i \
		-e '/^index /d' \
		-e '/^new file mode /d' \
		-e '/^Index:/d' \
		-e '/^=========/d' \
		-e '/^RCS file:/d' \
		-e '/^retrieving/d' \
		-e '/^diff/d' \
		-e '/^Files .* differ$/d' \
		-e '/^Only in /d' \
		-e '/^Common subdirectories/d' \
		-e '/^deleted file mode [0-9]*$/d' \
		-e '/^+++/s:\t.*::' \
		-e '/^---/s:\t.*::' \
		"$@"
}

skipit() {
	# filter some funky tree-wide cvs noise
	case $1 in
	4a57cad00081641b9f08117d79ee85cac6b72c77|\
	96aa7f2865689e314b4483fd5d7f277654e8a694|\
	8296a0d16cf62c337e0705eda712d920aea6c131|\
	a155cf9e46c8849ba5593063a7a15d886895a491|\
	"")
	return 1
	esac
	return 0
}

echo "cleaning up commits from main tree ..."

rm -rf work
mkdir -p work/patches
cd work

commits=( $(sed -n '/@GITLOG@/,$p' "../doit.sh" | awk '$1 == "#commit" { print $NF }' | tac) )

(
set -x

filter_1_4=true
for f in "${commits[@]}" ; do
	skipit $f || continue
	p=$(g fp -1 --no-stat $f -o patches/$f/)

	echo "processing $p"

	mkdir -p orig-${p%/*}
	cp $p orig-$p

	(
	fops=()
	${filter_1_4} && fops+=( --exclude '*/gcc-config-1.4' --exclude '*/gcc-config-1.4.0' --exclude '*/gcc-config-1.4.1' )
	filterdiff \
		--include '*/sys-devel/gcc-config/*' \
		--exclude '*/sys-devel/gcc-config/files/gcc-config-*-multi-ldpath' \
		--exclude '*/files/fake-ctarget.sh' \
		--exclude '*.ebuild' \
		--exclude '*/ChangeLog' \
		--exclude '*/Manifest' \
		--exclude '*/metadata.xml' \
		--exclude '*/files/digest-*' \
		"${fops[@]}" \
		$p > $p.bak
	sed \
		-e 's:Gentoo Technologies, Inc.:Gentoo Foundation:g' \
		-e 's:GNU General Public License, v2 or later:GNU General Public License:g' \
		-e '/Header:/{s: [^ ]*/sys-devel/gcc-config: gentoo-x86/sys-devel/gcc-config:;s:/Attic/:/:}' \
		$p.bak > $p
	scrub_patch $p

	case $f in
	0aefd02aaf4627e805e51b579747b4b6489d6ee0)
		sed -i 's|1.1.1.1 2005/11/30 09:53:56 chriswhite|1.1 2005/08/04 03:40:05 vapier|' $p
		;;
	esac

	grep -q '^--- ' $p || rm -f $p
	) &

	case ${f} in
	3775ee5c38da7f5a9f0161c2f9616833c541827b) filter_1_4=false ;;
	esac
done
wait
rm -f */*.bak
rmdir */ 2>/dev/null || :
) >log.main 2>log.main.x



echo "creating new git tree ..."

(
mkdir -p git
pushd git >/dev/null
g init .
cp ../../doit.sh ./
export GIT_AUTHOR_DATE="Jul 1 00:00:00 1982 +0000"
export GIT_COMMITTER_DATE="${GIT_AUTHOR_DATE}"
g a doit.sh
g ci -s -m 'script for migrating from cvs history'
g rm doit.sh
g ci -s -m 'drop script; archived for posterity only'
popd >/dev/null

export GIT_{AUTHOR,COMMITTER}_{DATE,EMAIL,NAME}

up() { sed -r 's:[[:space:]]+$::' ../$1 > ${2:-$1} ; echo "../$1 -> ${2:-$1}" ; }
set -x
lv=1.0
g="gcc-config"
w="wrapper"
pit="patch -p4 -f"
for f in "${commits[@]}" ; do
	skipit $f || continue
	p=$(echo patches/$f/*.patch)
	printf '######### %s\n' "$f"
	if [[ -z ${p} ]] ; then
		p=$(echo orig-patches/$f/*.patch)
		echo "Filtered patch: $(sed -n 4p $p)"
		diffstat "$p"
		continue
	fi
	printf '%s\n%s\n' "$(sed -n 3p ${p})" "${p#patches/}"
	if ! ${pit} < "$p" --dry-run  >/dev/null ; then
		printf '%s < %s --dry-run\n' "$pit" "$p"
		exit 1
	fi
	${pit} < "$p"
	ls -l

	log=$(g l -1 --pretty=%B $f -- | sed 's:(Portage version. [^)]*)::')

	pushd git >/dev/null
	gv= wv=
	a=()
	case $f in
	34e863500494f8cc32de33d53d633e5d69a944c8)
		gv=1.0 ; a+=(${g}) ;;
	95594434378a0cfed97c74bda1263e47fa093d9d)
		gv=1.1 ;;
	c2ede72ce8b3bff1c04ba0519c12debe69081361)
		gv=1.2 ;;
#	aeae0c3d3a92f56c94e2f6f8776c59915b933ef9)
#		delete code
	a71a8c962958ce8ee054a3b70d4c83c1b6967625)
		gv=1.2.1 ;;
	d7ef96d170ca87c450e48e5929940782d13b5d65)
		gv=1.2.2 ;; # up cc; up cpp; a+=(cc cpp) ;;
	17b5b13fced5791a971e110f28a3084f8591ca27)
		gv=1.2.3 ;;
	041c0c45e65c996c034f5d8e72f1c7871c186f5f)
		gv=1.2.4 ;; # g rm -f cc cpp ;;
	75253a1c0108dc8c9ad15074aaeef00e86ce68cb)
		gv=1.2.4 ;;
	53446c0e8e503c0b1ea4913286fffa85755d0dae)
		gv=1.2.5 ;;
	0ee2bf67be77672379b260f6faa222bad1f54873)
		gv=1.2.6 ;;
	0baaa470cdb0ff44a553945963ed5710156e733e|\
	a05ff61b962f3f1b31f21315a5ae268b521d0dc5)
		gv=1.2.7 ;;
	a15319dc2d52adc0a44684b9118754772b97567f)
		gv=1.2.8 ; up ${w}.c; a+=(${w}.c) ;;
	da68d82db171ec9448afac7093ca3f4b9c037cf6)
		gv=1.2.9 ; up ${w}.c ;;
	afe087376c53af9f50537168eafcacc3debf7a65)
		gv=1.3.0 ; up ${w}.c ;;
	da45b6f101a89a407f4a55bf000670f5e3e1b30b|\
	933521d89eb3a95df2600cad93deed1994db67ab)
		gv=1.3.1 ; up ${w}.c ;;
	a3b9ebb055f66f6afd7acce2b53ebd55393cfd56)
		gv=1.3.1 ;;
	5ab2ff596e4c6669a337676a511e59d7d4106720)
		gv=1.3.1 wv=1.4 ;;
	a5f418f3352b4fdb9c630fdd2ff152be3eb24148)
		gv=1.3.1 ;;
	f328fc10ef86075a312f45867f61e0269d61fe6c)
		gv=1.3.2 ;;
	9b8056a1f8ea76ec631825d77527afac5c8f09a6|\
	cab354934283baf4048187bc658ed2e3cbb1e6fc|\
	f16829e7981c43a4cffb077b7dd9108be0fa16b9)
		gv=1.3.3 wv=1.4.1 ;;
#	a05867e1ceda7bcffdcffb076c1e19f34616f2bf)
#		delete code
	fea469a14afc7548448697ea03befa44f601c920)
		gv=1.3.4 ;;
	e0a13622190d1e86b73ad47e3c2665642441e9bb|\
	e59829600d1333a01cb2e5fc0c2fe1f6b0ab1439|\
	0dfc873eff0730027a89a5ba4d80ffe5a5177335|\
	86f8f7105a83736a8622af0506e6864cd963d9f0)
		gv=1.3.5 wv=1.4.2 ;;
#	0155369165b800802a223c9f9c8bbb4793235ed2)
#		delete code
#	dd7fa598328061e24a332f00bb22bb92d7848002)
#		copyright/license tweak we handle in all commits
#	f24bab94ba22eeb552fbb0d0a68d59bcafa65efd)
#		delete code
	d3fd9324ce2226e2ff9f11adcef5c786419595c9|\
	cb3a38546e79868acc94397b350be5aaf470476a|\
	e1602511f11b8c413dbb9079f217137c3330fe33|\
	b3159d1300428326cd98569db532e4bf251f1d96|\
	29955e4c85a8073ff98f1d4bfd015d3b38c5f33b|\
	16298c38d32ee8759d1221735dbdf123212cf49a|\
	cfd928accee2dd2b50fb9eb564c9d63622880545|\
	b540dd9b0e1da7809a4b662c05a08acd20f48643|\
	7a53b40200a99de886da4dc02b808e008d0282fa)
		gv=1.3.6 wv=1.4.2 ;;
#	d4a20b30f4dc996f75f71e3d4010b4dfc2a65f5a)
#		delete code
	c0f87ee8987a82e98c15c73505503dabf83299c4|\
	810361581538c69880d1f1815741befb0eb38489|\
	66bcee579b234503a26fb95910888d929c05bb9c|\
	0985f585ca5cf566f6d81838610b7fc886d89b3b)
		gv=1.3.7 ;;
#	4f1b4c6cc50da9b7be6c0cb7729345c14e9887b0)
#		 wv=1.4.3 ;;	unreleased code
	cb49991b012a40573a6d2d00b3793d8c15bda8d9|\
	60046e07985df81fd0c5ba922eb215b7abd86dfe|\
	b959aa00406d8a8c0b2027500061246309bd618e|\
	30e7ef54b04f456836c7d0a5f200621caa48490b|\
	eb8a7a802299a229d62820c2ca86973ce8148e0a)
		gv=1.3.7 ;;
	58fe694e1b6d042f760ea09c75f03daa19bdbc88|\
	26144abfa9a1a5086b5969963d3d3192d2fc0275)
		gv=1.3.7 wv=1.4.2 ;;
	06c661b1f728565e586fd56f42ad6ac542ffced0|\
	25e700d79789b8ad538f15c32865bc3b71b91559)
		gv=1.3.8 wv=1.4.3 ;;
#	043c89686d90d62ef24f09dc6ed7e3a5d4f22300|\
#	fc46d3bef740e4e5b4955f2884bc9518e7b4ec5b)
#		revert 1.3.8 changes and move them into 1.3.9
#	875443f8abbbd13b3ddb9c00a4f7fc05dcab79b3|\
#	d17c4d5eedbe1c8c811c011cbcfb6af139292672)
#		delete code
	399a30873b41c5c030ceb6f3a73810ef03402b9e)
		gv=1.3.8 ;;
	966b63cab89c2e0800019a863f5f04936d80630f)    # same as 61 but in unreleased 1.3.9 ; hijack transition
		gv=1.3.9 wv=1.4.4 ;;
	44b6731d38d6494dab0ab041bd83f1c6229d77ff|\
	bb2e524c1102db343bc8da22d6e9dee0dd76f2ba)
		gv=1.3.9 ;;
	877227dffa4da41ee1ef1f39dfd69fa3e3a7da27|\
	db82802a4ae83df4ca8ce1527c812c95a58b6ed0|\
	8bde2fa15f4335eeca72f22e1b17446c830c1607|\
	3078445eda887d462f442a798c53ede77d2d7663|\
	8379860b242bf8211d74432ad54646e624d70ea9)
		gv=1.3.10 wv=1.4.5 ;;
	d79a9555cc00b458ece11ffb7d8f6977cacb71cc|\
	2fe74de7d96164c030665fe8c9fd04ade7780617|\
	765954bb305a7079818602a5b3126060ae96b1e2|\
	6b47b584eedf53f73906bb54d350533ef9ed6811|\
	07e46fd624db5c14c96fe8a07f7f485153c309c4|\
	8cc4058db5abf5539480ca3fb23170576d55051e|\
	f0e6cfe0b69eb0a82086f46bf214d4a584438923|\
	87c22656570bd2cc63b240a5726a010ad882c663|\
	c25d1a819522d9aa1cfabc2d315a3b826d173c6d)
		gv=1.3.10 wv=1.4.6 ;;
#	b4ee25ea31356cc082684ba7b9e8d9d00c425a71)
#		delete code
	2f963d4e2bcca2311a223d85411b4120fd43480a|\
	415ffe45b8e8a7c557549108b9304d0ae464ab71|\
	73eddb5635476d7ca537a2517f8bd6621cf21d93|\
	4b449e72f46bcc86283121235a11bf1e036ed734|\
	76c46c9d4f392ed92ccee3b49030c597baab35c3|\
	da525ec9d14f6f648d03b145fe416210f82d8870)
		gv=1.3.11 wv=1.4.6 ;;
	aaa448802304a6ee384c592251fb2b9647a8e09b|\
	b94f0cec38422f67eb5b8d8ea2b67039b0269b84|\
	6ffeb6c8b14b63c8f4d0f63055398f18d72ec282)
		gv=1.3.12 wv=1.4.6 ;;
#	7e2b5bead1158127c01649e38b3edd1e4f676d2f)
#		delete code
	1b4496732dc33d234133d9203342e770dda96d36|\
	c2e1a1fb6ad87164d4dd87d08c77a3ce5309f2f2|\
	4635546833307a5f1b54dab10baba84ed678ee70|\
	8a2d38ed55fc65773e2a8f59516a48025d4fcf24|\
	b2a1fd18d82522e080a7277f9e7c0d9f7ae54f84|\
	9419b45a97161142328099a8cf4a0ed283a48120|\
	23ddcdde88eb2fdc569d3e49992f50fa7ae18a1a|\
	5ee03c3c888fe1b4e18f37e119a882edc615c123|\
	1838fc0baac80cf898af0601e95476b0b1dbd691|\
	26342655b7aee2089d9e97c8ca685c68c8c9435a|\
	c87c00464d73f2847dec992ed71eac0b7b6ec8d0)
		gv=1.3.12 wv=1.4.7 ;;
#	284a5e3771cfabf88b812fc9bfa4c6d3a919056e)
#		delete code
	a6af208f85341ce4f4802623161621f3c5fcec7c|\
	af7b6f17ace8573d480f5d9e966846889ca1c926|\
	fda4ec5cb22b742324772bf9279ca0e485619850|\
	ebfc0684e9ac5851a3a5ee0d0e98f50fda2658d0|\
	8e6d4d08d2f76e074d11fc5995de64441b67709e|\
	65691a35d57cbba101d599c0e31e205b01861868|\
	dfd6e79a1a5bd3803c2b44d0771d9fa554c9e4ce|\
	3b84ceb7df7ec95eba1206072aaf56fa907fac77|\
	f2df0b15b7615a21893a62bf14996918f0a37aa8|\
	3ac38261f6f426ed55a52650dcebc11328105b43|\
	5244145f2681f8bdc0d941260c78fbd8fe9645f6|\
	e9c69b9a05fa3db30f177a8e793371c3baf6ec98)
		gv=1.3.13 ;;
	cc016bd5e07f20447767e093e3ef29686591271f|\
	1c5e4671d9a9867a0549768ee0cf3adc391eae8f)
		gv=1.3.14 ;;
	0c7847da5949dbf88a4d19f40bee6b2cf77a8a11|\
	481dd8baeaed4a952cef17b936fa31655f6b68b1|\
	b0f17d09dab4f3675f072737a8fafe18ca17beb4|\
	46f003a469b0130803b7b4d95a63ff595b501d3d)
		gv=1.3.15 ;;
	e4b83d5875786620555f04dad1453168da58664a|\
	c4b9eaf13e8dbe951a496681d392d3f749bb0482)
		gv=1.3.16 wv=1.4.8 ;;
	5e3d44b46492938942530f9c12cdfcc65a76346a|\
	c1d26297bd8e70d7bce80cf713120995cc8e66aa|\
	20d1676df3941eba6bcd4e29da5bf9925a169fb8|\
	5a47773aa7c33e046a947c3ccb5062d52cb30f02|\
	4a533964106101466a725fe0883d4762d26f21fc|\
	dc4fd61fdc1ca07d51e0c9ca2c348322e75b4aa9|\
	a25deedbd93ef2d296f2b38612875a7f69093f0e|\
	f32a67e3011fd52e220aa2ed4a389611b6738587|\
	bfc3552c6ee4c04d332312462f706f1051ef9ab3|\
	2fd5a33db8af5d21dca1d079ec68519a16ebdf3c|\
	ef1e57a083b95c007010acc098cc5cad43422ff0)
		gv=1.4.0 wv=1.5.0 ;;
#	0aefd02aaf4627e805e51b579747b4b6489d6ee0)
#		delete code
	4244b542c4b7284269092afe5aaf604e262b9b6b|\
	04b6e2113147115746ba38697a9d3862718c4904|\
	b424146b48d6983297da5b56ff4017b7ebdbd5d5|\
	ad113955154591ac86454be1c6f8787786e579f7)
		gv=1.4.1 wv=1.5.1 ;;
#	ead6b64c24ca54a6b1c5451d81881a932338fcf0)
#		delete code
	08dbe8cbbcfaeb097a41bc910fdb90f70814b046|\
	715390b064e7b4b9bf286dee2134cfa1dfb226bb|\
	2e96c50e078c3c23f341e870e958f8b5e1a7d324|\
	5760751c967e213a4e2b09a64b17727de731646a)
		gv=1.5 ;;
	b34f89b2436c9a5f2b235c995d000875aed322b9|\
	dad4d91b543fd765804379b764a9eb0c3ae78057|\
	9d3d146a691b65a7ee06911402a068cc555c4031|\
	0ca9b0ccb3c8ec6e3731be23bc74e9c3da73dcf1|\
	10fc621be7bc692aa35e2d91b078e1d951bd882d)
		gv=1.5 wv=1.5.2 ;;
	246f4c5f63f3bf220ec66ff22ad8e9d45f815cc4|\
	3c5715b565bf3acef5f158e5def7f6e98c82e16d)
		gv=1.5.1 ;;
	*)
		echo "Skipping ..."
		popd >/dev/null
		continue ;;
	esac

	if [[ ${lv} != ${gv} ]] ; then
		g t v${lv}
		lv=${gv}
	fi

	[[ -n ${gv} ]] && up ${g}-${gv} ${g} && chmod a+rx ${g}
	[[ -n ${wv} ]] && up ${w}-${wv}.c ${w}.c
	[[ ${#a[@]} -gt 0 ]] && g a ${a[@]}

	eval $(awk '{
		if ($1 == "From:") {
			name = $2" "$3
			email = gensub(/[<>]/, "", "g", $4)
			print "export GIT_AUTHOR_NAME=\"" name  "\""
			print "export GIT_AUTHOR_EMAIL=\"" email  "\""
		} else if ($1 == "Date:") {
			date = $3" "$4" "$5" "$6" "$7
			print "export GIT_AUTHOR_DATE=\"" date "\""
		}
	}' "../${p}")
	GIT_COMMITTER_DATE=$GIT_AUTHOR_DATE
	GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
	GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME

	g ci -q -a -m "$log"
	popd >/dev/null
done

cd git
g t v${lv}
) >log.git 2>log.git.x

# 1.4 was a bad series:
# <=25 Oct 2004:
#	versions before this were never released and appear
#	to be initial distcc/cross-compile hacking
#	gcc-config-1.4
# <=09 Aug 2005:
#	this was part of the "eselect-compiler" series that
#	was never unmasked and eventually scuttled
#	gcc-config-1.4.0

# This was created with:
#	cd sys-devel/gcc-config/files
#	git log . > f
#
# @GITLOG@
#commit 3c5715b565bf3acef5f158e5def7f6e98c82e16d
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Mar 15 01:16:44 2012 +0000
#
#    Use CTARGET from the env.d file by default to better work with custom GCC_VER.
#    
#    (Portage version: 2.2.0_alpha90/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.5.1 |   12 ++++++++----
# 1 files changed, 8 insertions(+), 4 deletions(-)
#
#commit 246f4c5f63f3bf220ec66ff22ad8e9d45f815cc4
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Feb 29 20:16:56 2012 +0000
#
#    Always sort runtime ld.so.conf paths and the install libgcc_s libraries based on version rather than defaulting to the selected profile #297685 by Scott McMurray. Fix gcc-config -E handling of GCC_SPECS #375091 by Bertrand Jacquin.
#    
#    (Portage version: 2.2.0_alpha86/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.5.1 |  759 +++++++++++++++++++++++++++
# 1 files changed, 759 insertions(+), 0 deletions(-)
#
#commit 10fc621be7bc692aa35e2d91b078e1d951bd882d
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Dec 7 05:42:19 2011 +0000
#
#    Fix multilib support with @GENTOO_LIBDIR@.
#    
#    (Portage version: 2.2.0_alpha79/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.4.1 |    8 ++++----
# sys-devel/gcc-config/files/gcc-config-1.5   |    8 ++++----
# 2 files changed, 8 insertions(+), 8 deletions(-)
#
#commit 0ca9b0ccb3c8ec6e3731be23bc74e9c3da73dcf1
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Nov 11 16:12:49 2011 +0000
#
#    Add a fallback when tac is unavailable as suggested by Alexis Ballier #390179.
#    
#    (Portage version: 2.2.0_alpha72/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.5 |   20 ++++++++++++++++----
# 1 files changed, 16 insertions(+), 4 deletions(-)
#
#commit 9d3d146a691b65a7ee06911402a068cc555c4031
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Jun 18 18:46:23 2011 +0000
#
#    Link g77/g95 to gfortran #278772 by Sébastien Fabbro.
#    
#    (Portage version: 2.2.0_alpha41/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/wrapper-1.5.2.c |   12 +++++++-----
# 1 files changed, 7 insertions(+), 5 deletions(-)
#
#commit dad4d91b543fd765804379b764a9eb0c3ae78057
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Mar 21 13:49:02 2011 +0000
#
#    Default to /etc/portage/make.conf #338032 by Dennis Schridde.
#    
#    (Portage version: 2.2.0_alpha26/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.5 |   15 +++++++++------
# 1 files changed, 9 insertions(+), 6 deletions(-)
#
#commit b34f89b2436c9a5f2b235c995d000875aed322b9
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Mar 18 19:47:37 2011 +0000
#
#    Stop auto appending CFLAGS_<abi> from the env.
#    
#    (Portage version: 2.2.0_alpha26/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/wrapper-1.5.2.c |  313 ++++++++++++++++++++++++++++
# 1 files changed, 313 insertions(+), 0 deletions(-)
#
#commit 5760751c967e213a4e2b09a64b17727de731646a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Mar 7 12:48:15 2011 +0000
#
#    Change "source /etc/profile" to ". /etc/profile" for dumb shells #349522 by Ulrich Müller.
#    
#    (Portage version: 2.2.0_alpha25/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.4.1 |   10 +++++-----
# sys-devel/gcc-config/files/gcc-config-1.5   |    8 ++++----
# 2 files changed, 9 insertions(+), 9 deletions(-)
#
#commit ead6b64c24ca54a6b1c5451d81881a932338fcf0
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Mar 7 12:44:40 2011 +0000
#
#    old
#
# sys-devel/gcc-config/files/gcc-config-1.3.16 |  757 -------------------------
# sys-devel/gcc-config/files/gcc-config-1.4.0  |  769 --------------------------
# sys-devel/gcc-config/files/wrapper-1.4.8.c   |  374 -------------
# sys-devel/gcc-config/files/wrapper-1.5.0.c   |  375 -------------
# 4 files changed, 0 insertions(+), 2275 deletions(-)
#
#commit 2e96c50e078c3c23f341e870e958f8b5e1a7d324
#Author: Ryan Hill <dirtyepic@gentoo.org>
#Date:   Tue Jan 18 07:04:36 2011 +0000
#
#    Add support for gccgo in 4.6. (bug #329551)
#    
#    (Portage version: 2.2.0_alpha17/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.5 |   10 +++++-----
# 1 files changed, 5 insertions(+), 5 deletions(-)
#
#commit 715390b064e7b4b9bf286dee2134cfa1dfb226bb
#Author: Fabian Groffen <grobian@gentoo.org>
#Date:   Sun Dec 27 16:03:53 2009 +0000
#
#    Fix typo in gcc-config, tsch -> tcsh, caused -E to use export iso setenv.  Not bumping as this bug in gcc-config went unnoticed for years.
#    (Portage version: 2.2.00.15134-prefix/cvs/Darwin powerpc)
#
# sys-devel/gcc-config/files/gcc-config-1.4.1 |    8 ++++----
# sys-devel/gcc-config/files/gcc-config-1.5   |    8 ++++----
# 2 files changed, 8 insertions(+), 8 deletions(-)
#
#commit 08dbe8cbbcfaeb097a41bc910fdb90f70814b046
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Dec 20 19:55:21 2009 +0000
#
#    Punt dead code (stdxx-incdir and GCC_SPECS checking), unify a bunch of common code constructs, improve error displaying in cases that dont matter, and add support for /etc/ld.so.conf.d/.
#    (Portage version: 2.2_rc60/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.5 |  725 +++++++++++++++++++++++++++++
# 1 files changed, 725 insertions(+), 0 deletions(-)
#
#commit ad113955154591ac86454be1c6f8787786e579f7
#Author: Mark Loeser <halcy0n@gentoo.org>
#Date:   Mon Aug 3 00:40:07 2009 +0000
#
#    Make --use-old work again, thanks to Brian Childs <brian AT rentec DOT com>; bug #221109
#    (Portage version: 2.2_rc33-r1/cvs/Linux i686)
#
# sys-devel/gcc-config/files/gcc-config-1.4.1 |    9 +++++----
# 1 files changed, 5 insertions(+), 4 deletions(-)
#
#commit b424146b48d6983297da5b56ff4017b7ebdbd5d5
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Jan 28 02:32:51 2009 +0000
#
#    Update libgcj.pc symlinks #136382 #216241 and set GCC_SPECS with -E #251271 by Diego E. Pettenò.
#    (Portage version: 2.2_rc23/cvs/Linux x86_64)
#
# sys-devel/gcc-config/files/gcc-config-1.4.1 |   37 +++++++++++++++++++++++---
# 1 files changed, 32 insertions(+), 5 deletions(-)
#
#commit 04b6e2113147115746ba38697a9d3862718c4904
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Jan 2 00:43:32 2009 +0000
#
#    optimize memory/string usage a bit more
#    (Portage version: 2.2_rc20/cvs/Linux 2.6.28 x86_64)
#
# sys-devel/gcc-config/files/wrapper-1.5.1.c |  113 ++++++++++++++++------------
# 1 files changed, 64 insertions(+), 49 deletions(-)
#
#commit 4244b542c4b7284269092afe5aaf604e262b9b6b
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Mar 16 01:20:11 2008 +0000
#
#    Support -C/--nocolor #204176 by Bapt.  Cleanup memory/string handling in the wrapper #207926 by Evan Teran.
#    (Portage version: 2.2_pre2)
#
# sys-devel/gcc-config/files/gcc-config-1.4.1 |  773 +++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.5.1.c  |  357 ++++++++++++
# 2 files changed, 1130 insertions(+), 0 deletions(-)
#
#commit 0aefd02aaf4627e805e51b579747b4b6489d6ee0
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Mar 16 01:18:53 2008 +0000
#
#    old
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |  712 ------------------------
# sys-devel/gcc-config/files/gcc-config-1.3.14 |  716 ------------------------
# sys-devel/gcc-config/files/gcc-config-1.3.15 |  757 --------------------------
# sys-devel/gcc-config/files/wrapper-1.4.7.c   |  377 -------------
# 4 files changed, 0 insertions(+), 2562 deletions(-)
#
#commit c92176918bd0f4769c65c302a6bd93d157082bb9
#Author: Robin H. Johnson <robbat2@gentoo.org>
#Date:   Thu Jan 31 12:35:44 2008 +0000
#
#    Remove all old-style digests from the system and regen the Manifest files.
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit ef1e57a083b95c007010acc098cc5cad43422ff0
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Dec 27 19:01:06 2007 +0000
#
#    Fix fallback CHOST detection when python is broken #203387 by Ambroz BIzjak.
#    (Portage version: 2.1.4_rc11)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    6 +++---
# 1 files changed, 3 insertions(+), 3 deletions(-)
#
#commit 6505d6ba5c010dfb4522fa068c542a8342b7680c
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Dec 1 18:50:47 2007 +0000
#
#    punt #199914
#    (Portage version: 2.1.4_rc4)
#
# .../gcc-config/files/digest-gcc-config-2.0.0_rc1   |    3 ---
# 1 files changed, 0 insertions(+), 3 deletions(-)
#
#commit 2fd5a33db8af5d21dca1d079ec68519a16ebdf3c
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Oct 11 05:27:57 2007 +0000
#
#    Make sure we dont create CTARGET-VER entries in env.d #195054.
#    (Portage version: 2.1.3.12)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    8 ++++++--
# 1 files changed, 6 insertions(+), 2 deletions(-)
#
#commit 77e841b322f2ca8b9809bfd06ddb7c8ad5f992d2
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Oct 11 05:27:23 2007 +0000
#
#    old
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit bfc3552c6ee4c04d332312462f706f1051ef9ab3
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Oct 7 04:20:36 2007 +0000
#
#    When querying for a current profile for a different target than the host, make sure we query the right target #193353.
#    (Portage version: 2.1.3.11)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit 4ff4300b59cbb27c612d61f99bb73dce6308198b
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Oct 7 04:19:26 2007 +0000
#
#    old
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit f32a67e3011fd52e220aa2ed4a389611b6738587
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Aug 31 01:42:47 2007 +0000
#
#    Rename NATIVE symlink to .NATIVE so it doesnt show up in listings and confuse people.
#    (Portage version: 2.1.3.7)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    5 +++--
# sys-devel/gcc-config/files/wrapper-1.5.0.c  |    4 ++--
# 2 files changed, 5 insertions(+), 4 deletions(-)
#
#commit b449340d9a1b32fbe6d17dd91cd79f4e996ad316
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Aug 31 01:41:57 2007 +0000
#
#    old
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit a25deedbd93ef2d296f2b38612875a7f69093f0e
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Aug 26 03:21:02 2007 +0000
#
#    Add a quick symlink for the native compiler gcc env.d so that by default, path look ups are fast even when working under a reduced PATH #190260 by Robert Buchholz.
#    (Portage version: 2.1.3.7)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    5 +++-
# sys-devel/gcc-config/files/wrapper-1.5.0.c  |   34 +++++++++++++++++---------
# 2 files changed, 26 insertions(+), 13 deletions(-)
#
#commit 42dfd67afc8e5b6ba8b3359dd8f6004ae76bb795
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Aug 26 03:19:27 2007 +0000
#
#    old
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit dc4fd61fdc1ca07d51e0c9ca2c348322e75b4aa9
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Aug 6 01:08:09 2007 +0000
#
#    default to gsed when possible
#    (Portage version: 2.1.3)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |   10 ++++++++--
# 1 files changed, 8 insertions(+), 2 deletions(-)
#
#commit 4a533964106101466a725fe0883d4762d26f21fc
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Jul 27 07:47:07 2007 +0000
#
#    update wrapper to match new gcc-config behavior where all env.d files contain full ctargets
#    (Portage version: 2.1.3_rc9)
#
# sys-devel/gcc-config/files/wrapper-1.5.0.c |   36 +++++++++------------------
# 1 files changed, 12 insertions(+), 24 deletions(-)
#
#commit 5a47773aa7c33e046a947c3ccb5062d52cb30f02
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Jul 25 14:33:01 2007 +0000
#
#    fix a few more places that need a -${CTARGET} postfix, add a --debug option, and make list_profiles nicer
#    (Portage version: 2.1.3_rc9)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |   48 +++++++++++++++++++-------
# 1 files changed, 35 insertions(+), 13 deletions(-)
#
#commit 20d1676df3941eba6bcd4e29da5bf9925a169fb8
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Jul 25 14:03:56 2007 +0000
#
#    move to binutils-config behavior where all env.d files have a -${CTARGET} postfix
#    (Portage version: 2.1.3_rc9)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |   30 ++++++++++++++------------
# 1 files changed, 16 insertions(+), 14 deletions(-)
#
#commit c1d26297bd8e70d7bce80cf713120995cc8e66aa
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue May 15 00:47:17 2007 +0000
#
#    fix up some errors in the PATH/ROOTPATH -> GCC_PATH conversion
#    (Portage version: 2.1.2.7)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |   14 +++++++++++---
# 1 files changed, 11 insertions(+), 3 deletions(-)
#
#commit 5e3d44b46492938942530f9c12cdfcc65a76346a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu May 3 05:20:39 2007 +0000
#
#    Move to GCC_PATH #174422 and make sure LDPATH is not re-ordered on us all the time #168884.
#    (Portage version: 2.1.2.5)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |  723 +++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.5.0.c  |  377 ++++++++++++++
# 2 files changed, 1100 insertions(+), 0 deletions(-)
#
#commit c4b9eaf13e8dbe951a496681d392d3f749bb0482
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed May 2 19:01:38 2007 +0000
#
#    Add a wrapper for gcov #175523.
#    (Portage version: 2.1.2.5)
#
# sys-devel/gcc-config/files/gcc-config-1.3.16 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit e4b83d5875786620555f04dad1453168da58664a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Apr 11 08:51:31 2007 +0000
#
#    Fabian Groffen says: remove alloca() usage #173998.
#    (Portage version: 2.1.2.3)
#
# sys-devel/gcc-config/files/gcc-config-1.3.16 |  757 ++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.4.8.c   |  374 +++++++++++++
# 2 files changed, 1131 insertions(+), 0 deletions(-)
#
#commit 46f003a469b0130803b7b4d95a63ff595b501d3d
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Mar 12 16:55:05 2007 +0000
#
#    fix minor typo #157694
#    (Portage version: 2.1.2.2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.15 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit b0f17d09dab4f3675f072737a8fafe18ca17beb4
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Mar 12 07:00:10 2007 +0000
#
#    Add wrappers for gcjh, gfortran, and the D language #157694 by Philipp Kirchner.
#    (Portage version: 2.1.2.2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.15 |    9 +++++----
# 1 files changed, 5 insertions(+), 4 deletions(-)
#
#commit c76ed2ac824f5cdf1dfcd88697a924a9add76300
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Mar 12 06:59:08 2007 +0000
#
#    old
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit 481dd8baeaed4a952cef17b936fa31655f6b68b1
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Dec 16 19:36:27 2006 +0000
#
#    some more tweaks/fixups from Kevin F. Quinn #125805
#    (Portage version: 2.1.2_rc3)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r4   |    1 -
# .../gcc-config/files/digest-gcc-config-1.3.14      |    1 -
# .../gcc-config/files/digest-gcc-config-1.3.15      |    1 -
# sys-devel/gcc-config/files/gcc-config-1.3.15       |   22 ++++++++++++++++---
# 4 files changed, 18 insertions(+), 7 deletions(-)
#
#commit f8ceb7d444eb56b7c953b3fa88bf621ff117f5bf
#Author: Gustavo Zacarias <gustavoz@gentoo.org>
#Date:   Mon Dec 11 13:07:07 2006 +0000
#
#    Stable on sparc wrt #157571
#    (Portage version: 2.1.1-r2)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r4   |    1 +
# .../gcc-config/files/digest-gcc-config-1.3.14      |    1 +
# .../gcc-config/files/digest-gcc-config-1.3.15      |    1 +
# 3 files changed, 3 insertions(+), 0 deletions(-)
#
#commit 06dbd1e33bc49d4d0df83609e63715290006178c
#Author: Andrej Kacian <ticho@gentoo.org>
#Date:   Sun Dec 10 08:03:05 2006 +0000
#
#    Stable on x86, bug #157571.
#    (Portage version: 2.1.2_rc2-r5)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r4   |    1 -
# .../gcc-config/files/digest-gcc-config-1.3.14      |    1 -
# .../gcc-config/files/digest-gcc-config-1.3.15      |    1 -
# 3 files changed, 0 insertions(+), 3 deletions(-)
#
#commit d7654d5caa47fe37245e0c44045e588736e39b39
#Author: Markus Rothe <corsair@gentoo.org>
#Date:   Sat Dec 9 21:16:11 2006 +0000
#
#    Stable on ppc64; bug #157571
#    (Portage version: 2.1.1-r2)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r4   |    1 +
# .../gcc-config/files/digest-gcc-config-1.3.14      |    1 +
# .../gcc-config/files/digest-gcc-config-1.3.15      |    1 +
# 3 files changed, 3 insertions(+), 0 deletions(-)
#
#commit 0c7847da5949dbf88a4d19f40bee6b2cf77a8a11
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Dec 9 07:33:09 2006 +0000
#
#    Add support by Kevin F. Quinn for handling multiple files in GCC_SPECS #125805.
#    (Portage version: 2.1.2_rc3)
#
# sys-devel/gcc-config/files/gcc-config-1.3.15 |  742 ++++++++++++++++++++++++++
# 1 files changed, 742 insertions(+), 0 deletions(-)
#
#commit 1c5e4671d9a9867a0549768ee0cf3adc391eae8f
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Oct 31 07:35:43 2006 +0000
#
#    use /etc/init.d/functions.sh rather than /sbin/functions.sh
#    (Portage version: 2.1.2_rc1-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |    6 +++---
# sys-devel/gcc-config/files/gcc-config-1.3.14 |    6 +++---
# 2 files changed, 6 insertions(+), 6 deletions(-)
#
#commit cc016bd5e07f20447767e093e3ef29686591271f
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Oct 19 04:01:49 2006 +0000
#
#    Make libgcc updates atomic #150257 by Diego.
#    (Portage version: 2.1.2_pre3-r4)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r4   |    1 -
# sys-devel/gcc-config/files/gcc-config-1.3.14       |  716 ++++++++++++++++++++
# 2 files changed, 716 insertions(+), 1 deletions(-)
#
#commit 802cd3fc9715249a7eea1814db20d50fa0549bb9
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Oct 2 11:54:15 2006 +0000
#
#    Bump to make sure everyone is using gcc-config-1 wrappers and not eselect.
#    (Portage version: 2.1.2_pre2)
#     (Signed Manifest commit)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r3   |    1 -
# 1 files changed, 0 insertions(+), 1 deletions(-)
#
#commit 1bf525f12c91fde59cc442f5b04161ce52c8f858
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Oct 2 11:54:06 2006 +0000
#
#    Bump to make sure everyone is using gcc-config-1 wrappers and not eselect.
#    (Portage version: 2.1.2_pre2)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r4   |    1 +
# 1 files changed, 1 insertions(+), 0 deletions(-)
#
#commit e9c69b9a05fa3db30f177a8e793371c3baf6ec98
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Aug 9 05:54:00 2006 +0000
#
#    make sure we dont leave $CTARGET-cc laying around since we no longer install it #143205
#    (Portage version: 2.1.1_pre4)
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |    4 +++-
# 1 files changed, 3 insertions(+), 1 deletions(-)
#
#commit 5244145f2681f8bdc0d941260c78fbd8fe9645f6
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Jul 5 23:36:31 2006 +0000
#
#    setup command envvars very early so we dont have to do stupid checks in sub code
#    (Portage version: 2.1.1_pre2-r2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |   10 +++++-----
# 1 files changed, 5 insertions(+), 5 deletions(-)
#
#commit 3ac38261f6f426ed55a52650dcebc11328105b43
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Jul 4 19:10:31 2006 +0000
#
#    if python is broken, at least warn the user #139180
#    (Portage version: 2.1.1_pre2-r2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |    3 ++-
# 1 files changed, 2 insertions(+), 1 deletions(-)
#
#commit f2df0b15b7615a21893a62bf14996918f0a37aa8
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Jul 3 18:57:51 2006 +0000
#
#    Push out accumulated fixes.
#    (Portage version: 2.1.1_pre2-r2)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r3   |    1 +
# sys-devel/gcc-config/files/gcc-config-1.3.13       |   22 ++++++++++----------
# 2 files changed, 12 insertions(+), 11 deletions(-)
#
#commit d814513f95f1bf4862ac16fd3024b5f13dda0b27
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Jul 3 18:57:20 2006 +0000
#
#    old
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r2   |    1 -
# 1 files changed, 0 insertions(+), 1 deletions(-)
#
#commit 3b84ceb7df7ec95eba1206072aaf56fa907fac77
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Jun 19 20:10:12 2006 +0000
#
#    try even harder to find CHOST when python is broken
#    (Portage version: 2.1.1_pre1-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |   26 +++++++++++++++++++++-----
# 1 files changed, 21 insertions(+), 5 deletions(-)
#
#commit 2ac95126e528b646b8d1b302c29148d1b010278c
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Tue Jun 6 01:49:05 2006 +0000
#
#    Updating gcc-config-2* ebuild to rc1, so users don't need to download a different tarball than for eselect-compiler when it gets unmasked.  There is actually no change in the wrapper other than the version number.
#    (Portage version: 2.1_rc4-r1)
#     (Signed Manifest commit)
#
# .../gcc-config/files/digest-gcc-config-2.0.0_beta2 |    3 ---
# 1 files changed, 0 insertions(+), 3 deletions(-)
#
#commit 0eb1201292336e7edc02be8943c1b270120f88d4
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Tue Jun 6 01:48:46 2006 +0000
#
#    Updating gcc-config-2* ebuild to rc1, so users don't need to download a different tarball than for eselect-compiler when it gets unmasked.  There is actually no change in the wrapper other than the version number.
#    (Portage version: 2.1_rc4-r1)
#
# .../gcc-config/files/digest-gcc-config-2.0.0_rc1   |    3 +++
# 1 files changed, 3 insertions(+), 0 deletions(-)
#
#commit dfd6e79a1a5bd3803c2b44d0771d9fa554c9e4ce
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Apr 25 00:20:17 2006 +0000
#
#    If active profile no longer exists, make sure -c spits out an error message.
#    (Portage version: 2.1_pre9-r4)
#
# .../gcc-config/files/digest-gcc-config-1.3.13-r2   |    1 +
# sys-devel/gcc-config/files/gcc-config-1.3.13       |   40 +++++++++++---------
# 2 files changed, 23 insertions(+), 18 deletions(-)
#
#commit 284a5e3771cfabf88b812fc9bfa4c6d3a919056e
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Apr 25 00:19:21 2006 +0000
#
#    old
#
# .../gcc-config/files/digest-gcc-config-1.3.12-r6   |    1 -
# .../gcc-config/files/digest-gcc-config-1.3.13-r1   |    1 -
# sys-devel/gcc-config/files/gcc-config-1.3.12       |  680 --------------------
# 3 files changed, 0 insertions(+), 682 deletions(-)
#
#commit 65691a35d57cbba101d599c0e31e205b01861868
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Apr 21 23:50:31 2006 +0000
#
#    change short --version from -v to -V
#    (Portage version: 2.1_pre9-r1)
#
# .../gcc-config/files/digest-gcc-config-1.3.12-r6   |    1 +
# .../gcc-config/files/digest-gcc-config-1.3.13-r1   |    1 +
# .../gcc-config/files/digest-gcc-config-2.0.0_beta2 |    2 ++
# sys-devel/gcc-config/files/gcc-config-1.3.12       |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.13       |    4 ++--
# 5 files changed, 8 insertions(+), 4 deletions(-)
#
#commit 8e6d4d08d2f76e074d11fc5995de64441b67709e
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Apr 15 00:45:53 2006 +0000
#
#    copy libgcc_s.so for all ROOT values #129121 by Bjarke Istrup Pedersen
#    (Portage version: 2.1_pre7-r5)
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit ebfc0684e9ac5851a3a5ee0d0e98f50fda2658d0
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Apr 3 01:05:59 2006 +0000
#
#    Generate a CTARGET-cpp wrapper if need be.
#    (Portage version: 2.1_pre7-r3)
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |   15 +++++++++------
# 1 files changed, 9 insertions(+), 6 deletions(-)
#
#commit fda4ec5cb22b742324772bf9279ca0e485619850
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Jan 8 09:52:45 2006 +0000
#
#    Ignore directores in /etc/env.d/gcc #118246 by Mark Purtill.
#    (Portage version: 2.1_pre3-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |    3 ++-
# sys-devel/gcc-config/files/gcc-config-1.3.13 |    3 ++-
# 2 files changed, 4 insertions(+), 2 deletions(-)
#
#commit af7b6f17ace8573d480f5d9e966846889ca1c926
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Jan 5 03:05:42 2006 +0000
#
#    Fix changing of profiles when using ROOT and a different CHOST.
#    (Portage version: 2.1_pre3-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |    8 +++++++-
# sys-devel/gcc-config/files/gcc-config-1.3.13 |   10 ++++++++--
# 2 files changed, 15 insertions(+), 3 deletions(-)
#
#commit a6af208f85341ce4f4802623161621f3c5fcec7c
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Dec 30 11:04:41 2005 +0000
#
#    Fix multilib copying of libraries #95622 by Diego Pettenò and restore copying of libgcc_s/libunwind when run from inside portage by using the mv instead of cp method of updating the libraries.
#    (Portage version: 2.1_pre2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.13 |  679 ++++++++++++++++++++++++++
# 1 files changed, 679 insertions(+), 0 deletions(-)
#
#commit c87c00464d73f2847dec992ed71eac0b7b6ec8d0
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Dec 27 02:45:48 2005 +0000
#
#    Use get_libdir #114633 by Patrick McLean.
#    (Portage version: 2.1_pre2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |   16 ++++++++++------
# 1 files changed, 10 insertions(+), 6 deletions(-)
#
#commit 26342655b7aee2089d9e97c8ca685c68c8c9435a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Dec 21 01:53:54 2005 +0000
#
#    fix the trailing / check for ROOT and silence grep if config doesnt exist
#    (Portage version: 2.0.53)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |    6 +++---
# 1 files changed, 3 insertions(+), 3 deletions(-)
#
#commit 1838fc0baac80cf898af0601e95476b0b1dbd691
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Dec 3 20:49:12 2005 +0000
#
#    handle the case where all we got was a CTARGET and no version
#    (Portage version: 2.0.53)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |   11 ++++++++++-
# 1 files changed, 10 insertions(+), 1 deletions(-)
#
#commit a155cf9e46c8849ba5593063a7a15d886895a491
#Merge: fbb708c 8296a0d
#Author: Chris White <chriswhite@gentoo.org>
#Date:   Wed Nov 30 09:54:11 2005 +0000
#
#    Merge from vendor branch FIX_VENDOR:
#    *** empty log message ***
#
#commit 8296a0d16cf62c337e0705eda712d920aea6c131
#Author: Chris White <chriswhite@gentoo.org>
#Date:   Wed Nov 30 09:54:11 2005 +0000
#
#    *** empty log message ***
#
# .../gcc-config/files/digest-gcc-config-2.0.0_beta2 |    1 +
# sys-devel/gcc-config/files/gcc-config-1.3.12       |  660 ++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.4.7.c         |  377 +++++++++++
# 3 files changed, 1038 insertions(+), 0 deletions(-)
#
#commit 5ee03c3c888fe1b4e18f37e119a882edc615c123
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Nov 19 05:23:08 2005 +0000
#
#    Add support for selecting profiles by version only.
#    (Portage version: 2.0.53_rc7)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |   16 +++++++++++-----
# 1 files changed, 11 insertions(+), 5 deletions(-)
#
#commit 7e2b5bead1158127c01649e38b3edd1e4f676d2f
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Nov 19 05:22:18 2005 +0000
#
#    old
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |  525 ----------------------
# sys-devel/gcc-config/files/gcc-config-1.3.11 |  599 --------------------------
# sys-devel/gcc-config/files/wrapper-1.4.5.c   |  409 ------------------
# sys-devel/gcc-config/files/wrapper-1.4.6.c   |  409 ------------------
# 4 files changed, 0 insertions(+), 1942 deletions(-)
#
#commit 23ddcdde88eb2fdc569d3e49992f50fa7ae18a1a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Nov 1 01:31:00 2005 +0000
#
#    Make sure we set env vars before trying to use them #111022 by Attila Stehr.
#    (Portage version: 2.0.53_rc6)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |    5 +++--
# 1 files changed, 3 insertions(+), 2 deletions(-)
#
#commit 36aaef71f4d05db82a56a1e5c70428dab63c5a8b
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Sun Oct 2 20:51:15 2005 +0000
#
#    Version bump with more backwards compat support (-B, -L, and -X).
#    (Portage version: 2.0.52-r1)
#
# .../gcc-config/files/digest-gcc-config-2.0.0_beta1 |    1 -
# .../gcc-config/files/digest-gcc-config-2.0.0_beta2 |    1 +
# 2 files changed, 1 insertions(+), 1 deletions(-)
#
#commit 13f1dc1a521ceb3f4be4e765d3af0a97256ce9ef
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Sat Oct 1 03:28:48 2005 +0000
#
#    Added gcc-config wrapper for beta version of eselect-compiler.  It still needs to be cleaned up a bit, but it's functional, so putting it into portage (package.mask still of course).
#    (Portage version: 2.0.52-r1)
#
# .../gcc-config/files/digest-gcc-config-2.0.0_beta1 |    1 +
# 1 files changed, 1 insertions(+), 0 deletions(-)
#
#commit 9419b45a97161142328099a8cf4a0ed283a48120
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Sep 18 04:51:24 2005 +0000
#
#    Add support for spaces in make.conf settings #105855.
#    (Portage version: 2.0.52-r1 http://ronaldmcnightrider.ytmnd.com/ )
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |   22 ++++++++++++++++++++--
# 1 files changed, 20 insertions(+), 2 deletions(-)
#
#commit b2a1fd18d82522e080a7277f9e7c0d9f7ae54f84
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Sep 2 05:05:28 2005 +0000
#
#    inform user they are switching cross/native compiler
#    (Portage version: 2.0.51.22-r2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |    8 ++++++--
# 1 files changed, 6 insertions(+), 2 deletions(-)
#
#commit 8a2d38ed55fc65773e2a8f59516a48025d4fcf24
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Aug 25 23:06:50 2005 +0000
#
#    Update list output to show the active version for all targets.
#    (Portage version: 2.0.51.22-r2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |   34 ++++++++++++++++++-------
# 1 files changed, 24 insertions(+), 10 deletions(-)
#
#commit 4635546833307a5f1b54dab10baba84ed678ee70
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Aug 20 07:36:08 2005 +0000
#
#    add some more sanity checks so spb will shut up
#    (Portage version: 2.0.51.22-r2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |   10 ++++++++--
# 1 files changed, 8 insertions(+), 2 deletions(-)
#
#commit 8fd191c7c37e89a049cdf1fdc72aeca512ac31d9
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Tue Aug 9 08:34:23 2005 +0000
#
#    Killing 1.4.0.  Working on gcc-config-2.0 in gentoo/src/toolchain/gcc-config.
#    (Portage version: 2.0.51.22-r2)
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit 3775ee5c38da7f5a9f0161c2f9616833c541827b
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Tue Aug 9 08:34:23 2005 +0000
#
#    Killing 1.4.0.  Working on gcc-config-2.0 in gentoo/src/toolchain/gcc-config.
#    (Portage version: 2.0.51.22-r2)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |  578 ---------------------------
# 1 files changed, 0 insertions(+), 578 deletions(-)
#
#commit c2e1a1fb6ad87164d4dd87d08c77a3ce5309f2f2
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Fri Aug 5 15:21:19 2005 +0000
#
#    Fix long option for -S (--split-profile).
#    (Portage version: 2.0.51.22-r2)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit 1b4496732dc33d234133d9203342e770dda96d36
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Aug 4 03:40:05 2005 +0000
#
#    Clean up the wrapper a bit.
#    (Portage version: 2.0.51.22-r2)
#
# sys-devel/gcc-config/files/wrapper-1.4.7.c |  377 ++++++++++++++++++++++++++++
# 1 files changed, 377 insertions(+), 0 deletions(-)
#
#commit 6ffeb6c8b14b63c8f4d0f63055398f18d72ec282
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Jul 23 05:05:52 2005 +0000
#
#    touchup code to not call strlen() so much and punt ugly C++/Java style macro
#    (Portage version: 2.0.51.22-r2)
#
# sys-devel/gcc-config/files/wrapper-1.4.6.c |   19 +++++++++----------
# 1 files changed, 9 insertions(+), 10 deletions(-)
#
#commit b94f0cec38422f67eb5b8d8ea2b67039b0269b84
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Jul 10 06:18:55 2005 +0000
#
#    when asking for the current profile of a cross target that has yet to be configured, make sure we error out
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.11 |    7 +++----
# sys-devel/gcc-config/files/gcc-config-1.3.12 |    7 +++----
# 2 files changed, 6 insertions(+), 8 deletions(-)
#
#commit aaa448802304a6ee384c592251fb2b9647a8e09b
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Jul 9 16:52:24 2005 +0000
#
#    Add support for parsing profile names so we can use it in toolchain.eclass.
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.12 |  612 ++++++++++++++++++++++++++
# 1 files changed, 612 insertions(+), 0 deletions(-)
#
#commit da525ec9d14f6f648d03b145fe416210f82d8870
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Jul 7 23:03:40 2005 +0000
#
#    Make sure the f77 wrapper is installed/run properly for g77 #97437 by John C. Vernaleo.
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.11 |    5 +++--
# sys-devel/gcc-config/files/wrapper-1.4.6.c   |    4 +++-
# 2 files changed, 6 insertions(+), 3 deletions(-)
#
#commit 166f8fc7040dd60aa4773c0e083fc420e90af3f3
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Jul 7 23:01:41 2005 +0000
#
#    old
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit 76c46c9d4f392ed92ccee3b49030c597baab35c3
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Jun 13 04:57:03 2005 +0000
#
#    Make sure that -c errors out if given an invalid TARGET.
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.11 |    8 ++++----
# 1 files changed, 4 insertions(+), 4 deletions(-)
#
#commit 1c13053e73b04da639ea365800a8459755bdaade
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Jun 13 04:56:34 2005 +0000
#
#    old
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit 4b449e72f46bcc86283121235a11bf1e036ed734
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Jun 7 22:49:54 2005 +0000
#
#    tweak for gcc-4 beta
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.11 |    6 ++++--
# 1 files changed, 4 insertions(+), 2 deletions(-)
#
#commit 73eddb5635476d7ca537a2517f8bd6621cf21d93
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Jun 7 22:42:28 2005 +0000
#
#    Make sure we support funky version strings (beta823942) and custom specs (hardened).
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.11 |   41 +++++++++++++++++++++++--
# 1 files changed, 37 insertions(+), 4 deletions(-)
#
#commit 415ffe45b8e8a7c557549108b9304d0ae464ab71
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Jun 7 00:39:09 2005 +0000
#
#    Cleanup the CHOST-GCCVER parsing so it isnt so fragile (and works with BSD hosts).
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.11 |   28 ++++++++++++++++++++-----
# 1 files changed, 22 insertions(+), 6 deletions(-)
#
#commit 2f963d4e2bcca2311a223d85411b4120fd43480a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Jun 6 03:58:40 2005 +0000
#
#    If python is broken due to libstdc++ changes or whatever, make sure gcc-config still works somewhat sanely.
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.11 |  548 ++++++++++++++++++++++++++
# 1 files changed, 548 insertions(+), 0 deletions(-)
#
#commit b4ee25ea31356cc082684ba7b9e8d9d00c425a71
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Jun 6 01:36:03 2005 +0000
#
#    old
#    (Portage version: 2.0.51.22-r1)
#
# sys-devel/gcc-config/files/gcc-config-1.3.8 |  502 ---------------------------
# sys-devel/gcc-config/files/wrapper-1.4.3.c  |  301 ----------------
# 2 files changed, 0 insertions(+), 803 deletions(-)
#
#commit c25d1a819522d9aa1cfabc2d315a3b826d173c6d
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Apr 28 23:42:25 2005 +0000
#
#    env -u -> env -i for BSD #90643
#    (Portage version: 2.0.51.20-r5)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.8  |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.4.0  |    2 +-
# 3 files changed, 5 insertions(+), 5 deletions(-)
#
#commit 029f4f046299d3df0d945fee21d1314b0cf46904
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Apr 28 23:42:25 2005 +0000
#
#    env -u -> env -i for BSD #90643
#    (Portage version: 2.0.51.20-r5)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit 87c22656570bd2cc63b240a5726a010ad882c663
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Apr 28 01:47:04 2005 +0000
#
#    cp -a -> cp -pP #90643
#    (Portage version: 2.0.51.20-r4)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.8  |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.4.0  |    2 +-
# 3 files changed, 5 insertions(+), 5 deletions(-)
#
#commit 5c2207109fafc06028f786a55bcb95d0be27178f
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Apr 28 01:47:04 2005 +0000
#
#    cp -a -> cp -pP #90643
#    (Portage version: 2.0.51.20-r4)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit f0e6cfe0b69eb0a82086f46bf214d4a584438923
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Apr 28 01:44:44 2005 +0000
#
#    cp -> $CP rm -> $RM touch -> $TOUCH etc... #90643
#    (Portage version: 2.0.51.20-r4)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |   35 +++++++++++++------------
# sys-devel/gcc-config/files/gcc-config-1.3.8  |   35 +++++++++++++------------
# sys-devel/gcc-config/files/gcc-config-1.4.0  |    2 +-
# 3 files changed, 37 insertions(+), 35 deletions(-)
#
#commit 81ec1cf251043da52ab8814333815cb17048251a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Apr 28 01:44:44 2005 +0000
#
#    cp -> $CP rm -> $RM touch -> $TOUCH etc... #90643
#    (Portage version: 2.0.51.20-r4)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |   59 ++++++++++++++-------------
# 1 files changed, 30 insertions(+), 29 deletions(-)
#
#commit 8cc4058db5abf5539480ca3fb23170576d55051e
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Apr 9 18:37:48 2005 +0000
#
#    use -maxdepth instead of -prune #87528
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.8  |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.4.0  |    2 +-
# 3 files changed, 5 insertions(+), 5 deletions(-)
#
#commit 5c7899de3c607a98cfadc7794fb6a0d4eb7d6877
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Apr 9 18:37:48 2005 +0000
#
#    use -maxdepth instead of -prune #87528
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit 07e46fd624db5c14c96fe8a07f7f485153c309c4
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Apr 1 23:56:47 2005 +0000
#
#    make sure we only scan /etc/env.d/gcc/ and no subdirs #87528
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.8  |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.4.0  |    2 +-
# 3 files changed, 5 insertions(+), 5 deletions(-)
#
#commit 8be643ef988bef34da54670e0468f962373342e5
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Apr 1 23:56:47 2005 +0000
#
#    make sure we only scan /etc/env.d/gcc/ and no subdirs #87528
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit 4990ed5ddd7c6258be1c19bf935374f24b1f113f
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Thu Mar 31 16:23:17 2005 +0000
#
#    Don't spit out -m64 warnings.  Closes bug #87130.
#    (Portage version: 2.0.51.19)
#
# 0 files changed, 0 insertions(+), 0 deletions(-)
#
#commit 6b47b584eedf53f73906bb54d350533ef9ed6811
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Mar 19 20:30:01 2005 +0000
#
#    Make sure we copy libunwind in addition to libgcc_s (for ia64 and such).  Also dont copy internal gcc libs while portage is calling us (causes python to segfault and crap).
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |   56 ++++++++++++++-----------
# sys-devel/gcc-config/files/gcc-config-1.3.8  |   54 ++++++++++++++-----------
# sys-devel/gcc-config/files/gcc-config-1.4.0  |    2 +-
# 3 files changed, 63 insertions(+), 49 deletions(-)
#
#commit 5e7574dc19f280e88d4ae3a0ed4ee8ce0a28f832
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Mar 19 20:30:01 2005 +0000
#
#    Make sure we copy libunwind in addition to libgcc_s (for ia64 and such).  Also dont copy internal gcc libs while portage is calling us (causes python to segfault and crap).
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |   57 ++++++++++++++------------
# 1 files changed, 31 insertions(+), 26 deletions(-)
#
#commit 765954bb305a7079818602a5b3126060ae96b1e2
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Mar 16 23:51:35 2005 +0000
#
#    dont kill /lib/cpp if host is solaris #79964
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.8  |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.4.0  |    2 +-
# 3 files changed, 5 insertions(+), 5 deletions(-)
#
#commit b17ec8b83dd7f73e063c73f7f8f52ec6e8d24558
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Mar 16 23:51:35 2005 +0000
#
#    dont kill /lib/cpp if host is solaris #79964
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit 0b5fabcb613d8c1fcc2f92002b1b5cf203f828f2
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Mar 16 23:32:12 2005 +0000
#
#    #include <wait.h> -> #include <sys/wait.h> #79911
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    2 +-
# 1 files changed, 1 insertions(+), 1 deletions(-)
#
#commit 2fe74de7d96164c030665fe8c9fd04ade7780617
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Mar 16 23:32:12 2005 +0000
#
#    #include <wait.h> -> #include <sys/wait.h> #79911
#    (Portage version: 2.0.51.19)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |    9 ++++-----
# sys-devel/gcc-config/files/gcc-config-1.3.8  |    9 ++++-----
# sys-devel/gcc-config/files/gcc-config-1.4.0  |    9 ++++-----
# sys-devel/gcc-config/files/wrapper-1.4.3.c   |    6 +++---
# sys-devel/gcc-config/files/wrapper-1.4.5.c   |    6 +++---
# sys-devel/gcc-config/files/wrapper-1.4.6.c   |    6 +++---
# 6 files changed, 21 insertions(+), 24 deletions(-)
#
#commit d70ab81a69986202b4f45cdcc6dfa06d79f4dc65
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Sat Mar 5 00:40:36 2005 +0000
#
#    Stop CFLAGS_* from entering env file.
#    (Portage version: 2.0.51.18)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    2 +-
# 1 files changed, 1 insertions(+), 1 deletions(-)
#
#commit 1081166877bc451de860bc2c569809fbcb460442
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Sat Mar 5 00:40:36 2005 +0000
#
#    Stop CFLAGS_* from entering env file.
#    (Portage version: 2.0.51.18)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit 1c300f22d3de7386646a41df7f350c6550bd0b9d
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Fri Mar 4 17:53:19 2005 +0000
#
#    Changing CTARGET_ALIASES to FAKE_TARGETS for consistency with binutils.
#    (Portage version: 2.0.51.18)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    2 +-
# 1 files changed, 1 insertions(+), 1 deletions(-)
#
#commit da476bf9bbffcb9dd7ef9e7f1ae7fcacf6d500b9
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Fri Mar 4 17:53:19 2005 +0000
#
#    Changing CTARGET_ALIASES to FAKE_TARGETS for consistency with binutils.
#    (Portage version: 2.0.51.18)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    6 +++---
# 1 files changed, 3 insertions(+), 3 deletions(-)
#
#commit 17b909cac39ad3360a3a3e28ad099b320cb93c14
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Fri Mar 4 12:22:21 2005 +0000
#
#    Cleaned up 1.4.0 a bit.  Got rid of the stupid fake-ctarget.sh stuff and added smarter logic for that into the gcc-config script.  Still in package.mask as it hits a sandbox bug.
#    (Portage version: 2.0.51.18)
#
# sys-devel/gcc-config/files/fake-ctarget.sh  |    4 ----
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    2 +-
# 2 files changed, 1 insertions(+), 5 deletions(-)
#
#commit 3e456498295a4c2703a51c2e72cf47a4cd07cefc
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Fri Mar 4 12:22:21 2005 +0000
#
#    Cleaned up 1.4.0 a bit.  Got rid of the stupid fake-ctarget.sh stuff and added smarter logic for that into the gcc-config script.  Still in package.mask as it hits a sandbox bug.
#    (Portage version: 2.0.51.18)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |   38 +++++++++++++++++----------
# 1 files changed, 24 insertions(+), 14 deletions(-)
#
#commit 1ce9c8fd4043e0f839580f179f6025eb0d7035ae
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Sun Feb 20 01:16:29 2005 +0000
#
#    Don't put CTARGET_ALIASES stuff in the env.
#    (Portage version: 2.0.51.16)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    2 +-
# 1 files changed, 1 insertions(+), 1 deletions(-)
#
#commit 37267c429c08003540755017ee0df4f800b121ae
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Sun Feb 20 01:16:29 2005 +0000
#
#    Don't put CTARGET_ALIASES stuff in the env.
#    (Portage version: 2.0.51.16)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    6 +++---
# 1 files changed, 3 insertions(+), 3 deletions(-)
#
#commit d79a9555cc00b458ece11ffb7d8f6977cacb71cc
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Sat Feb 19 10:04:01 2005 +0000
#
#    1.3.10-r1 stable on amd64.  Removing 1.3.9.  Adding 1.4.0 which adds support for creating ctarget aliases based on the GCC_CTARGET_ALIASES variable in the /etc/env.d/gcc/ config file.  This is setup automatically on multilib profiles with recent gcc emerges.
#    (Portage version: 2.0.51.16)
#
# sys-devel/gcc-config/files/fake-ctarget.sh  |    4 +
# sys-devel/gcc-config/files/gcc-config-1.3.9 |  501 ---------------------------
# sys-devel/gcc-config/files/gcc-config-1.4.0 |    2 +-
# sys-devel/gcc-config/files/wrapper-1.4.4.c  |  386 ---------------------
# sys-devel/gcc-config/files/wrapper-1.4.6.c  |  408 ++++++++++++++++++++++
# 5 files changed, 413 insertions(+), 888 deletions(-)
#
#commit 0077e7567bbf554837e9aa1bdcdb37ecf9f975d5
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Sat Feb 19 10:04:01 2005 +0000
#
#    1.3.10-r1 stable on amd64.  Removing 1.3.9.  Adding 1.4.0 which adds support for creating ctarget aliases based on the GCC_CTARGET_ALIASES variable in the /etc/env.d/gcc/ config file.  This is setup automatically on multilib profiles with recent gcc emerges.
#    (Portage version: 2.0.51.16)
#
# sys-devel/gcc-config/files/gcc-config-1.4.0 |  563 +++++++++++++++++++++++++++
# 1 files changed, 563 insertions(+), 0 deletions(-)
#
#commit 8379860b242bf8211d74432ad54646e624d70ea9
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Mon Feb 7 19:24:21 2005 +0000
#
#    Fix comment.
#    (Portage version: 2.0.51-r15)
#
# sys-devel/gcc-config/files/wrapper-1.4.5.c |    7 +++----
# 1 files changed, 3 insertions(+), 4 deletions(-)
#
#commit 3078445eda887d462f442a798c53ede77d2d7663
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Feb 4 00:10:39 2005 +0000
#
#    use /usr/lib/misc instead of /usr/libexec
#    (Portage version: 2.0.51-r15)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |    8 ++++----
# 1 files changed, 4 insertions(+), 4 deletions(-)
#
#commit 8bde2fa15f4335eeca72f22e1b17446c830c1607
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Tue Feb 1 05:38:27 2005 +0000
#
#    Make gcc-config support gcc version strings containing '-'.  This allows for wider multislot support.
#    (Portage version: 2.0.51-r15)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |   16 +++++++++++-----
# 1 files changed, 11 insertions(+), 5 deletions(-)
#
#commit db82802a4ae83df4ca8ce1527c812c95a58b6ed0
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Mon Jan 31 06:16:58 2005 +0000
#
#    Fix argv[0].
#    (Portage version: 2.0.51-r15)
#
# sys-devel/gcc-config/files/wrapper-1.4.5.c |   10 +++++++---
# 1 files changed, 7 insertions(+), 3 deletions(-)
#
#commit 877227dffa4da41ee1ef1f39dfd69fa3e3a7da27
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Mon Jan 31 05:39:30 2005 +0000
#
#    Multilib fixes.  Copies libgcc_s.so* to the correct location for all abis.  Allows command line args to override ${ABI}.  This should resolve bugs #78306 and #78652.
#    (Portage version: 2.0.51-r15)
#
# sys-devel/gcc-config/files/gcc-config-1.3.10 |  513 ++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.4.5.c   |  406 ++++++++++++++++++++
# 2 files changed, 919 insertions(+), 0 deletions(-)
#
#commit bb2e524c1102db343bc8da22d6e9dee0dd76f2ba
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Jan 19 23:26:13 2005 +0000
#
#    make sure $ROOT has a trailing /
#    (Portage version: 2.0.51-r13)
#
# sys-devel/gcc-config/files/gcc-config-1.3.8 |    3 ++-
# sys-devel/gcc-config/files/gcc-config-1.3.9 |    3 ++-
# 2 files changed, 4 insertions(+), 2 deletions(-)
#
#commit 44b6731d38d6494dab0ab041bd83f1c6229d77ff
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Jan 7 20:14:57 2005 +0000
#
#    move multilib into unstable
#
# sys-devel/gcc-config/files/gcc-config-1.3.9 |   32 ++++++++++++++++----------
# 1 files changed, 20 insertions(+), 12 deletions(-)
#
#commit 966b63cab89c2e0800019a863f5f04936d80630f
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Wed Jan 5 08:31:53 2005 +0000
#
#    Push ccache fixes into 1.3.9 as well...
#
# sys-devel/gcc-config/files/gcc-config-1.3.9 |   16 +++++++++-------
# 1 files changed, 9 insertions(+), 7 deletions(-)
#
#commit 399a30873b41c5c030ceb6f3a73810ef03402b9e
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Jan 5 05:33:34 2005 +0000
#
#    Make sure that when we switch compilers, we dont accidently invalidate all of our ccache data #70548.
#
# sys-devel/gcc-config/files/gcc-config-1.3.8 |   16 +++++++++-------
# 1 files changed, 9 insertions(+), 7 deletions(-)
#
#commit d17c4d5eedbe1c8c811c011cbcfb6af139292672
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Jan 4 16:17:13 2005 +0000
#
#    old
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |  484 ---------------------------
# sys-devel/gcc-config/files/wrapper-1.4.2.c  |  312 -----------------
# 2 files changed, 0 insertions(+), 796 deletions(-)
#
#commit 875443f8abbbd13b3ddb9c00a4f7fc05dcab79b3
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Dec 29 01:09:22 2004 +0000
#
#    punt 1.3.7 and fix ChangeLog
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |  520 ---------------------------
# 1 files changed, 0 insertions(+), 520 deletions(-)
#
#commit fc46d3bef740e4e5b4955f2884bc9518e7b4ec5b
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Dec 29 01:05:58 2004 +0000
#
#    push ABI changes into 1.3.9 so 1.3.8 can go stable
#
# sys-devel/gcc-config/files/gcc-config-1.3.8 |    7 +-
# sys-devel/gcc-config/files/gcc-config-1.3.9 |  490 +++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.4.3.c  |  301 ++++++++++++++++
# 3 files changed, 795 insertions(+), 3 deletions(-)
#
#commit 043c89686d90d62ef24f09dc6ed7e3a5d4f22300
#Author: Jeremy Huddleston <eradicator@gentoo.org>
#Date:   Tue Dec 28 05:32:10 2004 +0000
#
#    Rolling in support for CFLAGS_${ABI}.  Rolling g{cc,++}{32,64} support into the wrapper.
#
# sys-devel/gcc-config/files/gcc-config-1.3.8 |    7 +-
# sys-devel/gcc-config/files/wrapper-1.4.3.c  |  301 ---------------------
# sys-devel/gcc-config/files/wrapper-1.4.4.c  |  386 +++++++++++++++++++++++++++
# 3 files changed, 389 insertions(+), 305 deletions(-)
#
#commit 25e700d79789b8ad538f15c32865bc3b71b91559
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Dec 24 05:46:24 2004 +0000
#
#    Seems people still have outdated gcc versions installed which break with GCC_SPECS="".  Add a warning if their gcc is broken so they know they have to re-emerge gcc.
#
# sys-devel/gcc-config/files/gcc-config-1.3.8 |   23 ++++++++++++++++++-----
# 1 files changed, 18 insertions(+), 5 deletions(-)
#
#commit 06c661b1f728565e586fd56f42ad6ac542ffced0
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Dec 23 18:04:06 2004 +0000
#
#    version bump
#
# sys-devel/gcc-config/files/gcc-config-1.3.8 |  478 +++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.4.3.c  |  206 +++++--------
# 2 files changed, 554 insertions(+), 130 deletions(-)
#
#commit 26144abfa9a1a5086b5969963d3d3192d2fc0275
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Dec 9 01:46:23 2004 +0000
#
#    err finish merging patch
#
# sys-devel/gcc-config/files/wrapper-1.4.2.c |    6 +++---
# 1 files changed, 3 insertions(+), 3 deletions(-)
#
#commit 58fe694e1b6d042f760ea09c75f03daa19bdbc88
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Dec 8 23:47:13 2004 +0000
#
#    Portability patch #73617 by Sunil.
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |    9 +++------
# sys-devel/gcc-config/files/wrapper-1.4.2.c  |   20 +++++++++-----------
# 2 files changed, 12 insertions(+), 17 deletions(-)
#
#commit eb8a7a802299a229d62820c2ca86973ce8148e0a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Dec 5 21:07:43 2004 +0000
#
#    make sure we delete /lib/cpp if no C++ support
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |   10 +++++++---
# 1 files changed, 7 insertions(+), 3 deletions(-)
#
#commit 30e7ef54b04f456836c7d0a5f200621caa48490b
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sun Dec 5 08:10:16 2004 +0000
#
#    Err, we want to handle GCC_SPECS, not GCC_CONFIG.  Also make sure duplicate paths arent duplicated in LDPATH now that gcc is exporting multiple spec files per ebuild.
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |   15 ++++++---------
# 1 files changed, 6 insertions(+), 9 deletions(-)
#
#commit b959aa00406d8a8c0b2027500061246309bd618e
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Dec 3 21:39:59 2004 +0000
#
#    Make sure GCC_CONFIG is taken only from the selected profile.
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |    3 ++-
# 1 files changed, 2 insertions(+), 1 deletions(-)
#
#commit 60046e07985df81fd0c5ba922eb215b7abd86dfe
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri Dec 3 02:43:33 2004 +0000
#
#    Version bump to add a lot of cross-compile fixes.  Also perform sanity checking on GCC_SPECS #68799, dont create wrappers in the ebuild #72745, and dont install /lib/cpp unless the system supports C++.
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |  170 ++++++++++++++-------------
# 1 files changed, 90 insertions(+), 80 deletions(-)
#
#commit cb49991b012a40573a6d2d00b3793d8c15bda8d9
#Author: Travis Tilley <lv@gentoo.org>
#Date:   Sun Nov 28 16:39:49 2004 +0000
#
#    Fixed Bug 72557, where gcc-config would get very confused with non-gcc-lib ldpaths
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |   10 +++++++---
# sys-devel/gcc-config/files/gcc-config-1.3.7 |   10 +++++++---
# 2 files changed, 14 insertions(+), 6 deletions(-)
#
#commit 4f1b4c6cc50da9b7be6c0cb7729345c14e9887b0
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Tue Oct 26 18:15:30 2004 +0000
#
#    Add GCCBITS support to wrapper.
#
# sys-devel/gcc-config/files/wrapper-1.4.3.c |  355 ++++++++++++++++++++++++++++
# 1 files changed, 355 insertions(+), 0 deletions(-)
#
#commit 0985f585ca5cf566f6d81838610b7fc886d89b3b
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Oct 26 04:05:36 2004 +0000
#
#    move 32bit/64bit wrappers out of toolchain.eclass
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |   18 ++++++++++++++++--
# 1 files changed, 16 insertions(+), 2 deletions(-)
#
#commit 66bcee579b234503a26fb95910888d929c05bb9c
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Tue Oct 26 03:14:01 2004 +0000
#
#    override umask #68699 and make sure we use a functional gcc-config version #68700
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |    4 +++-
# 1 files changed, 3 insertions(+), 1 deletions(-)
#
#commit d4a20b30f4dc996f75f71e3d4010b4dfc2a65f5a
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Oct 25 13:57:29 2004 +0000
#
#    remove old files
#
# sys-devel/gcc-config/files/gcc-config-1.4   |  550 ------------------------
# sys-devel/gcc-config/files/gcc-config-1.4.1 |  600 ---------------------------
# sys-devel/gcc-config/files/wrapper-1.4.1.c  |  311 --------------
# sys-devel/gcc-config/files/wrapper-1.4.c    |  228 ----------
# sys-devel/gcc-config/files/wrapper.c        |  141 -------
# 5 files changed, 0 insertions(+), 1830 deletions(-)
#
#commit 810361581538c69880d1f1815741befb0eb38489
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Oct 13 19:46:19 2004 +0000
#
#    remove extra quote
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |    4 ++--
# 1 files changed, 2 insertions(+), 2 deletions(-)
#
#commit c0f87ee8987a82e98c15c73505503dabf83299c4
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Oct 13 16:29:04 2004 +0000
#
#    new version; phear !
#
# sys-devel/gcc-config/files/gcc-config-1.3.7 |  491 +++++++++++++++++++++++++++
# 1 files changed, 491 insertions(+), 0 deletions(-)
#
#commit f24bab94ba22eeb552fbb0d0a68d59bcafa65efd
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Wed Oct 13 13:34:25 2004 +0000
#
#    clean
#
# sys-devel/gcc-config/files/gcc-config-1.3.5        |  457 --------------------
# .../gcc-config/files/gcc-config-1.3.5-multi-ldpath |  438 -------------------
# 2 files changed, 0 insertions(+), 895 deletions(-)
#
#commit 7a53b40200a99de886da4dc02b808e008d0282fa
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Oct 11 14:36:40 2004 +0000
#
#    touchup output of list to indicate current profile
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |   10 +++++++---
# 1 files changed, 7 insertions(+), 3 deletions(-)
#
#commit b540dd9b0e1da7809a4b662c05a08acd20f48643
#Author: Travis Tilley <lv@gentoo.org>
#Date:   Tue Oct 5 12:25:45 2004 +0000
#
#    fixed the handling of GCC_SPECS-specific gcc configs
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |    9 +++++++--
# 1 files changed, 7 insertions(+), 2 deletions(-)
#
#commit cfd928accee2dd2b50fb9eb564c9d63622880545
#Author: Travis Tilley <lv@gentoo.org>
#Date:   Mon Oct 4 15:52:15 2004 +0000
#
#    make gcc-config give an error message if the current profile doesnt exist
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |   29 +++++++++++++++++---------
# 1 files changed, 19 insertions(+), 10 deletions(-)
#
#commit 16298c38d32ee8759d1221735dbdf123212cf49a
#Author: Travis Tilley <lv@gentoo.org>
#Date:   Sat Oct 2 12:21:18 2004 +0000
#
#    added the fix for bug 63973
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |    6 +++---
# sys-devel/gcc-config/files/gcc-config-1.4   |    6 +++---
# sys-devel/gcc-config/files/gcc-config-1.4.1 |    6 +++---
# 3 files changed, 9 insertions(+), 9 deletions(-)
#
#commit dd7fa598328061e24a332f00bb22bb92d7848002
#Author: Sven Wegener <swegener@gentoo.org>
#Date:   Tue Sep 28 02:02:09 2004 +0000
#
#    Gentoo Technologies, Inc. -> Gentoo Foundation
#
# sys-devel/gcc-config/files/wrapper-1.4.c |    4 ++--
# sys-devel/gcc-config/files/wrapper.c     |    4 ++--
# 2 files changed, 4 insertions(+), 4 deletions(-)
#
#commit 0155369165b800802a223c9f9c8bbb4793235ed2
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Mon Sep 20 13:55:18 2004 +0000
#
#    old
#
# sys-devel/gcc-config/files/gcc-config-1.3.3        |  446 --------------------
# .../gcc-config/files/gcc-config-1.3.3-multi-ldpath |  446 --------------------
# sys-devel/gcc-config/files/gcc-config-1.3.4        |  446 --------------------
# .../gcc-config/files/gcc-config-1.3.4-multi-ldpath |  446 --------------------
# 4 files changed, 0 insertions(+), 1784 deletions(-)
#
#commit 29955e4c85a8073ff98f1d4bfd015d3b38c5f33b
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu Aug 19 15:16:25 2004 +0000
#
#    touchup gcc-config errors since at first glance they look like shell errors
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |    4 ++--
# sys-devel/gcc-config/files/wrapper-1.4.1.c  |    9 +++++----
# sys-devel/gcc-config/files/wrapper-1.4.2.c  |   10 +++++-----
# 3 files changed, 12 insertions(+), 11 deletions(-)
#
#commit b3159d1300428326cd98569db532e4bf251f1d96
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sat Jul 24 20:40:14 2004 +0000
#
#    Some cleanup that remove use of which from ferret <james.noble@worc.ox.ac.uk>,
#    bug #55262.
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |   21 ++++++---------------
# 1 files changed, 6 insertions(+), 15 deletions(-)
#
#commit e1602511f11b8c413dbb9079f217137c3330fe33
#Author: Daniel Black <dragonheart@gentoo.org>
#Date:   Sun Jul 18 04:44:54 2004 +0000
#
#    Manifest fix - files/wrapper-1.4.1.c size mismatch, files/wrapper-1.4.2.c size mismatch, files/wrapper-1.4.c size mismatch, files/wrapper.c size mismatch
#
# sys-devel/gcc-config/files/wrapper-1.4.1.c |    2 +-
# sys-devel/gcc-config/files/wrapper-1.4.2.c |    2 +-
# sys-devel/gcc-config/files/wrapper-1.4.c   |    2 +-
# sys-devel/gcc-config/files/wrapper.c       |    2 +-
# 4 files changed, 4 insertions(+), 4 deletions(-)
#
#commit cb3a38546e79868acc94397b350be5aaf470476a
#Author: Aron Griffis <agriffis@gentoo.org>
#Date:   Thu Jul 15 01:05:25 2004 +0000
#
#    Gentoo Technologies -> Gentoo Foundation
#
# sys-devel/gcc-config/files/gcc-config-1.3.3        |    4 ++--
# .../gcc-config/files/gcc-config-1.3.3-multi-ldpath |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.4        |    4 ++--
# .../gcc-config/files/gcc-config-1.3.4-multi-ldpath |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.5        |    4 ++--
# .../gcc-config/files/gcc-config-1.3.5-multi-ldpath |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.3.6        |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.4          |    4 ++--
# sys-devel/gcc-config/files/gcc-config-1.4.1        |    4 ++--
# 9 files changed, 18 insertions(+), 18 deletions(-)
#
#commit d3fd9324ce2226e2ff9f11adcef5c786419595c9
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sat Jun 19 17:53:18 2004 +0000
#
#    Make sure we cleanup stale wrappers, bug #36388.
#
# sys-devel/gcc-config/files/gcc-config-1.3.6 |  471 +++++++++++++++++++++++++++
# 1 files changed, 471 insertions(+), 0 deletions(-)
#
#commit 86f8f7105a83736a8622af0506e6864cd963d9f0
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Fri May 7 00:45:06 2004 +0000
#
#    fix #29950 #48492 and more !
#
# sys-devel/gcc-config/files/gcc-config-1.3.5 |   53 ++++++++++++++++++---------
# 1 files changed, 36 insertions(+), 17 deletions(-)
#
#commit 0ca7eb7233c4b91ca698d5105c1a7a70e339524e
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu May 6 23:04:43 2004 +0000
#
#    also port changes to multi-ldpath
#
# .../gcc-config/files/gcc-config-1.3.5-multi-ldpath |   60 +++++++++-----------
# 1 files changed, 26 insertions(+), 34 deletions(-)
#
#commit 0dfc873eff0730027a89a5ba4d80ffe5a5177335
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Thu May 6 23:01:19 2004 +0000
#
#      clean up the help output, add support for -v|--version and -h|--help options,
#      and then add the version to the gcc-config after installing
#
# sys-devel/gcc-config/files/gcc-config-1.3.5 |   60 ++++++++++++---------------
# 1 files changed, 26 insertions(+), 34 deletions(-)
#
#commit e59829600d1333a01cb2e5fc0c2fe1f6b0ab1439
#Author: Mike Frysinger <vapier@gentoo.org>
#Date:   Sat Mar 6 04:21:44 2004 +0000
#
#    we license under gpl2, not gpl2 or later
#
# sys-devel/gcc-config/files/gcc-config-1.3.3        |    7 +++----
# .../gcc-config/files/gcc-config-1.3.3-multi-ldpath |    7 +++----
# sys-devel/gcc-config/files/gcc-config-1.3.4        |    7 +++----
# .../gcc-config/files/gcc-config-1.3.4-multi-ldpath |    7 +++----
# sys-devel/gcc-config/files/gcc-config-1.3.5        |    7 +++----
# .../gcc-config/files/gcc-config-1.3.5-multi-ldpath |    7 +++----
# sys-devel/gcc-config/files/gcc-config-1.4          |    7 +++----
# sys-devel/gcc-config/files/gcc-config-1.4.1        |    6 +++---
# 8 files changed, 24 insertions(+), 31 deletions(-)
#
#commit e0a13622190d1e86b73ad47e3c2665642441e9bb
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sun Feb 8 16:52:01 2004 +0000
#
#    Update wrapper to also treat symlinks as valid targets - this fixes a problem
#    where -gcc called the symlink, and not the proper binary. Also fix a few
#    issues where we used data->tmp as they can cause possible corruption when used
#    in recursive calls and child functions.  Closes bug #39162.
#
# sys-devel/gcc-config/files/gcc-config-1.3.5        |  447 ++++++++++++++++++++
# .../gcc-config/files/gcc-config-1.3.5-multi-ldpath |  447 ++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.4.2.c         |  314 ++++++++++++++
# 3 files changed, 1208 insertions(+), 0 deletions(-)
#
#commit a05867e1ceda7bcffdcffb076c1e19f34616f2bf
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Tue Nov 18 19:46:47 2003 +0000
#
#    Cleanup
#
# sys-devel/gcc-config/files/digest-gcc-config-1.2.7 |    2 -
# sys-devel/gcc-config/files/digest-gcc-config-1.2.9 |    3 -
# sys-devel/gcc-config/files/digest-gcc-config-1.3.0 |    3 -
# sys-devel/gcc-config/files/digest-gcc-config-1.3.1 |    9 -
# .../gcc-config/files/digest-gcc-config-1.3.1-r1    |    3 -
# sys-devel/gcc-config/files/digest-gcc-config-1.3.2 |    3 -
# sys-devel/gcc-config/files/gcc-config-1.2.7        |  416 -------------------
# sys-devel/gcc-config/files/gcc-config-1.2.9        |  357 -----------------
# sys-devel/gcc-config/files/gcc-config-1.3.0        |  357 -----------------
# sys-devel/gcc-config/files/gcc-config-1.3.1        |  410 -------------------
# sys-devel/gcc-config/files/gcc-config-1.3.2        |  418 --------------------
# 11 files changed, 0 insertions(+), 1981 deletions(-)
#
#commit fea469a14afc7548448697ea03befa44f601c920
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Tue Nov 18 19:39:07 2003 +0000
#
#    I did not use REAL_CHOST in all cases, ending up with /usr/bin/-gcc, etc
#    files, as CHOST was not set.
#
# sys-devel/gcc-config/files/gcc-config-1.3.4        |  447 ++++++++++++++++++++
# .../gcc-config/files/gcc-config-1.3.4-multi-ldpath |  447 ++++++++++++++++++++
# 2 files changed, 894 insertions(+), 0 deletions(-)
#
#commit 9134c4ec0e29162b4d9f183747e0f9d5c5a099da
#Author: Brad House <brad_mssw@gentoo.org>
#Date:   Sat Oct 18 19:36:04 2003 +0000
#
#    amd64 necessary changes for gcc-3.3.1-r5
#
# .../gcc-config/files/gcc-config-1.3.3-multi-ldpath |  447 ++++++++++++++++++++
# 1 files changed, 447 insertions(+), 0 deletions(-)
#
#commit 4a57cad00081641b9f08117d79ee85cac6b72c77
#Author: Robin H. Johnson <robbat2@gentoo.org>
#Date:   Thu Jul 3 05:04:22 2003 +0000
#
#    removing lockfile
#
# sys-devel/gcc-config/files/.frozen |    1 -
# 1 files changed, 0 insertions(+), 1 deletions(-)
#
#commit 96aa7f2865689e314b4483fd5d7f277654e8a694
#Author: Robin H. Johnson <robbat2@gentoo.org>
#Date:   Thu Jul 3 02:13:43 2003 +0000
#
#    Add frozen lock support
#
# sys-devel/gcc-config/files/.frozen |    1 +
# 1 files changed, 1 insertions(+), 0 deletions(-)
#
#commit f16829e7981c43a4cffb077b7dd9108be0fa16b9
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Mon Apr 28 02:14:30 2003 +0000
#
#    fix for when portageq not in path
#
# sys-devel/gcc-config/files/gcc-config-1.3.3 |    7 ++++---
# 1 files changed, 4 insertions(+), 3 deletions(-)
#
#commit cab354934283baf4048187bc658ed2e3cbb1e6fc
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sat Apr 12 21:19:26 2003 +0000
#
#    update wrapper for cross compile, bug #18933
#
# sys-devel/gcc-config/files/wrapper-1.4.1.c |   51 ++++++++++------------------
# 1 files changed, 18 insertions(+), 33 deletions(-)
#
#commit 9b8056a1f8ea76ec631825d77527afac5c8f09a6
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sat Apr 12 18:44:22 2003 +0000
#
#    New version
#    - lots of speed improvements to wrapper
#    - short options
#    - select profile by number
#
# sys-devel/gcc-config/files/gcc-config-1.3.3 |  446 +++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.4.1.c  |  325 +++++++++++++++++++
# 2 files changed, 771 insertions(+), 0 deletions(-)
#
#commit 17b0639bfe197ec10885f75a370c718c0659f61d
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Tue Apr 8 12:56:27 2003 +0000
#
#    digest
#
# sys-devel/gcc-config/files/digest-gcc-config-1.2.7 |    7 -------
# sys-devel/gcc-config/files/digest-gcc-config-1.2.9 |    8 +-------
# sys-devel/gcc-config/files/digest-gcc-config-1.3.0 |    8 +-------
# .../gcc-config/files/digest-gcc-config-1.3.1-r1    |    8 +-------
# sys-devel/gcc-config/files/digest-gcc-config-1.3.2 |    4 ++--
# 5 files changed, 5 insertions(+), 30 deletions(-)
#
#commit f328fc10ef86075a312f45867f61e0269d61fe6c
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Tue Apr 8 12:53:38 2003 +0000
#
#    optimizations; use new wrapper
#
# sys-devel/gcc-config/files/digest-gcc-config-1.3.2 |    3 +
# sys-devel/gcc-config/files/gcc-config-1.3.2        |  418 ++++++++++++++++++++
# sys-devel/gcc-config/files/gcc-config-1.4.1        |   27 +-
# 3 files changed, 442 insertions(+), 6 deletions(-)
#
#commit 4325d9fe98da869bc0adc8eb5fb63dfe7ef36316
#Author: Zack Welch <zwelch@gentoo.org>
#Date:   Sun Apr 6 22:19:01 2003 +0000
#
#    fix distcc/cross-compile builds; fix return bug in gcc-config script
#
# sys-devel/gcc-config/files/digest-gcc-config-1.3.1 |    9 +++++++++
# .../gcc-config/files/digest-gcc-config-1.3.1-r1    |    5 +++--
# 2 files changed, 12 insertions(+), 2 deletions(-)
#
#commit a5f418f3352b4fdb9c630fdd2ff152be3eb24148
#Author: Zack Welch <zwelch@gentoo.org>
#Date:   Sun Apr 6 22:19:01 2003 +0000
#
#    fix distcc/cross-compile builds; fix return bug in gcc-config script
#
# sys-devel/gcc-config/files/digest-gcc-config-1.2.7 |    9 +
# sys-devel/gcc-config/files/digest-gcc-config-1.2.9 |    9 +
# sys-devel/gcc-config/files/digest-gcc-config-1.3.0 |    9 +
# .../gcc-config/files/digest-gcc-config-1.3.1-r1    |    8 +
# sys-devel/gcc-config/files/gcc-config-1.3.1        |    4 +-
# sys-devel/gcc-config/files/gcc-config-1.4.1        |  585 ++++++++++++++++++++
# 6 files changed, 622 insertions(+), 2 deletions(-)
#
#commit 5ab2ff596e4c6669a337676a511e59d7d4106720
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sun Feb 23 16:20:10 2003 +0000
#
#    add new wrapper and gcc-config script
#
# sys-devel/gcc-config/files/gcc-config-1.4 |  551 +++++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper-1.4.c  |  228 ++++++++++++
# 2 files changed, 779 insertions(+), 0 deletions(-)
#
#commit a3b9ebb055f66f6afd7acce2b53ebd55393cfd56
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Wed Feb 19 23:23:26 2003 +0000
#
#    speed related fixes
#
# sys-devel/gcc-config/files/gcc-config-1.3.1 |   30 ++++++++++++++++++++------
# 1 files changed, 23 insertions(+), 7 deletions(-)
#
#commit 933521d89eb3a95df2600cad93deed1994db67ab
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sun Jan 19 23:39:05 2003 +0000
#
#    more fixes
#
# sys-devel/gcc-config/files/wrapper.c |   13 +++++++++----
# 1 files changed, 9 insertions(+), 4 deletions(-)
#
#commit da45b6f101a89a407f4a55bf000670f5e3e1b30b
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sun Jan 19 19:14:52 2003 +0000
#
#    minor fixes
#
# sys-devel/gcc-config/files/gcc-config-1.3.1 |  394 +++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper.c        |   13 +-
# 2 files changed, 404 insertions(+), 3 deletions(-)
#
#commit afe087376c53af9f50537168eafcacc3debf7a65
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Wed Jan 15 22:28:10 2003 +0000
#
#    fix gcc not finding internal headers, bug #8132
#
# sys-devel/gcc-config/files/gcc-config-1.3.0 |  357 +++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper.c        |    6 +-
# 2 files changed, 362 insertions(+), 1 deletions(-)
#
#commit da68d82db171ec9448afac7093ca3f4b9c037cf6
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Wed Jan 15 01:59:58 2003 +0000
#
#    fix wrapper calling cc-config
#
# sys-devel/gcc-config/files/gcc-config-1.2.3 |  302 --------------------
# sys-devel/gcc-config/files/gcc-config-1.2.4 |  335 ----------------------
# sys-devel/gcc-config/files/gcc-config-1.2.5 |  384 -------------------------
# sys-devel/gcc-config/files/gcc-config-1.2.6 |  403 ---------------------------
# sys-devel/gcc-config/files/gcc-config-1.2.8 |  357 ------------------------
# sys-devel/gcc-config/files/gcc-config-1.2.9 |  357 ++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper.c        |    6 +-
# 7 files changed, 360 insertions(+), 1784 deletions(-)
#
#commit a15319dc2d52adc0a44684b9118754772b97567f
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Wed Jan 15 00:25:33 2003 +0000
#
#    add wrappers to ~x86
#
# sys-devel/gcc-config/files/gcc-config-1.2.8 |  357 +++++++++++++++++++++++++++
# sys-devel/gcc-config/files/wrapper.c        |  125 ++++++++++
# 2 files changed, 482 insertions(+), 0 deletions(-)
#
#commit a05ff61b962f3f1b31f21315a5ae268b521d0dc5
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Thu Jan 2 21:40:41 2003 +0000
#
#    change usage screen; bug #13005.
#
# sys-devel/gcc-config/files/gcc-config-1.2.7 |   51 +++++++++++++--------------
# 1 files changed, 25 insertions(+), 26 deletions(-)
#
#commit 0baaa470cdb0ff44a553945963ed5710156e733e
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Wed Dec 25 21:37:47 2002 +0000
#
#    add colorgcc support, bug #12689
#
# sys-devel/gcc-config/files/gcc-config-1.2.7 |  417 +++++++++++++++++++++++++++
# 1 files changed, 417 insertions(+), 0 deletions(-)
#
#commit 0ee2bf67be77672379b260f6faa222bad1f54873
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Tue Dec 24 18:26:45 2002 +0000
#
#    remove broken /usr/bin/cpp binary if exists
#
# sys-devel/gcc-config/files/gcc-config-1.2.6 |  403 +++++++++++++++++++++++++++
# 1 files changed, 403 insertions(+), 0 deletions(-)
#
#commit 53446c0e8e503c0b1ea4913286fffa85755d0dae
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Mon Dec 23 01:49:50 2002 +0000
#
#    add --print-environ; other fixes
#
# sys-devel/gcc-config/files/gcc-config-1.2.5 |  384 +++++++++++++++++++++++++++
# 1 files changed, 384 insertions(+), 0 deletions(-)
#
#commit 75253a1c0108dc8c9ad15074aaeef00e86ce68cb
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Tue Dec 17 13:06:48 2002 +0000
#
#    small fixes
#
# sys-devel/gcc-config/files/gcc-config-1.2.4 |   12 +++++++++---
# 1 files changed, 9 insertions(+), 3 deletions(-)
#
#commit 041c0c45e65c996c034f5d8e72f1c7871c186f5f
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Mon Dec 16 18:45:53 2002 +0000
#
#    add --list-profiles
#
# sys-devel/gcc-config/files/cc               |    3 -
# sys-devel/gcc-config/files/cpp              |    3 -
# sys-devel/gcc-config/files/gcc-config-1.2   |  279 -----------------------
# sys-devel/gcc-config/files/gcc-config-1.2.1 |  279 -----------------------
# sys-devel/gcc-config/files/gcc-config-1.2.2 |  282 -----------------------
# sys-devel/gcc-config/files/gcc-config-1.2.4 |  329 +++++++++++++++++++++++++++
# 6 files changed, 329 insertions(+), 846 deletions(-)
#
#commit 17b5b13fced5791a971e110f28a3084f8591ca27
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Mon Dec 16 18:13:02 2002 +0000
#
#    updates for /lib/cpp and /usr/bin/cc wrappers
#
# sys-devel/gcc-config/files/gcc-config-1.2.3 |  302 +++++++++++++++++++++++++++
# 1 files changed, 302 insertions(+), 0 deletions(-)
#
#commit d7ef96d170ca87c450e48e5929940782d13b5d65
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Mon Dec 16 04:19:05 2002 +0000
#
#    new version
#
# sys-devel/gcc-config/files/cc               |    3 +
# sys-devel/gcc-config/files/cpp              |    3 +
# sys-devel/gcc-config/files/gcc-config-1.2.2 |  282 +++++++++++++++++++++++++++
# 3 files changed, 288 insertions(+), 0 deletions(-)
#
#commit a71a8c962958ce8ee054a3b70d4c83c1b6967625
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Wed Nov 27 21:45:37 2002 +0000
#
#    users should be able to get the bin, lib, etc path ..
#
# sys-devel/gcc-config/files/gcc-config-1.2.1 |  279 +++++++++++++++++++++++++++
# 1 files changed, 279 insertions(+), 0 deletions(-)
#
#commit aeae0c3d3a92f56c94e2f6f8776c59915b933ef9
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sun Nov 10 18:36:58 2002 +0000
#
#    cleanup
#
# sys-devel/gcc-config/files/gcc-config-1.0 |   98 -------------
# sys-devel/gcc-config/files/gcc-config-1.1 |  213 -----------------------------
# 2 files changed, 0 insertions(+), 311 deletions(-)
#
#commit c2ede72ce8b3bff1c04ba0519c12debe69081361
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sun Nov 10 15:17:26 2002 +0000
#
#    new version
#
# sys-devel/gcc-config/files/gcc-config-1.2 |  279 +++++++++++++++++++++++++++++
# 1 files changed, 279 insertions(+), 0 deletions(-)
#
#commit 95594434378a0cfed97c74bda1263e47fa093d9d
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sun Nov 10 11:58:19 2002 +0000
#
#    new version
#
# sys-devel/gcc-config/files/gcc-config-1.1 |  213 +++++++++++++++++++++++++++++
# 1 files changed, 213 insertions(+), 0 deletions(-)
#
#commit 34e863500494f8cc32de33d53d633e5d69a944c8
#Author: Martin Schlemmer <azarah@gentoo.org>
#Date:   Sun Oct 27 22:38:11 2002 +0000
#
#    initial version
#
# sys-devel/gcc-config/files/gcc-config-1.0 |   98 +++++++++++++++++++++++++++++
# 1 files changed, 98 insertions(+), 0 deletions(-)
