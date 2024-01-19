import 'package:Medito/constants/colors/color_constants.dart';
import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:Medito/models/home/editorial/editorial_model.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animated_scale_widget.dart';

class EditorialWidget extends ConsumerWidget {
  const EditorialWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var response = ref.watch(fetchEditorialProvider);

    return response.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: true,
      data: (data) {
        return _buildMain(context, data);
      },
      error: (err, stack) => MeditoErrorWidget(
        message: err.toString(),
        onTap: () => ref.refresh(fetchQuoteProvider),
        isLoading: response.isLoading,
        isScaffold: false,
      ),
      loading: () => const EditorialShimmerWidget(),
    );
  }

  AnimatedScaleWidget _buildMain(BuildContext context, EditorialModel data) {
    var titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontFamily: SourceSerif,
          color: ColorConstants.walterWhite,
          fontSize: 24,
        );
    var subtitleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontFamily: DmSans,
          color: ColorConstants.walterWhite,
        );
    var size = MediaQuery.of(context).size;

    var boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: LinearGradient(
        begin: FractionalOffset.topCenter,
        end: FractionalOffset.bottomCenter,
        colors: [
          ColorConstants.black.withOpacity(0.0),
          ColorConstants.black.withOpacity(0.8),
        ],
        stops: [0.3, 0.9],
      ),
    );

    return AnimatedScaleWidget(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: padding20),
        child: InkWell(
          onTap: () => handleNavigation(
            context: context,
            data.type,
            [data.path.toString().getIdFromPath(), data.path],
          ),
          child: Stack(
            children: [
              _buildCoverImage(size, data),
              Container(
                width: size.width,
                height: 200,
                decoration: boxDecoration,
                padding: EdgeInsets.all(padding16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: titleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      data.subtitle,
                      style: subtitleStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ClipRRect _buildCoverImage(Size size, EditorialModel data) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size.width,
        height: 200,
        child: NetworkImageWidget(
          url: data.imageUrl,
        ),
      ),
    );
  }
}
